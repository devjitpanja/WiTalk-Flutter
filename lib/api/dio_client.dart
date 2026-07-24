import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';

String? _cachedBuildNumber;

Future<String> _getAppBuildNumber() async {
  if (_cachedBuildNumber != null && _cachedBuildNumber!.isNotEmpty) {
    return _cachedBuildNumber!;
  }
  try {
    final info = await PackageInfo.fromPlatform();
    _cachedBuildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : '62';
  } catch (_) {
    _cachedBuildNumber = '62';
  }
  return _cachedBuildNumber!;
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ForceLogoutEvent {
  final String reason;
  final String message;
  ForceLogoutEvent({required this.reason, required this.message});
}

class TokenRefreshResult {
  final bool success;
  final String? accessToken;
  final String? refreshToken;
  final bool isNetworkError;
  final bool isSessionExpired;

  TokenRefreshResult({
    required this.success,
    this.accessToken,
    this.refreshToken,
    this.isNetworkError = false,
    this.isSessionExpired = false,
  });
}

// Global stream for force logout events
final _forceLogoutController = StreamController<ForceLogoutEvent>.broadcast();
Stream<ForceLogoutEvent> get onForceLogout => _forceLogoutController.stream;

void _emitForceLogout(String reason, String message) {
  _forceLogoutController.add(ForceLogoutEvent(reason: reason, message: message));
}

// Token cache to avoid repeated async reads
class _TokenCache {
  String? accessToken;
  String? refreshToken;
  int? tokenExpiry;
  int cachedAt = 0;
}

final _tokenCache = _TokenCache();
const _tokenCacheTtl = 30 * 1000; // 30 seconds

void clearTokenCache() {
  _tokenCache.accessToken = null;
  _tokenCache.refreshToken = null;
  _tokenCache.tokenExpiry = null;
  _tokenCache.cachedAt = 0;
}

// Token readiness gate
bool _isTokensReady = false;
Completer<void>? _tokenReadinessCompleter;

void markTokensAsReady() {
  AppLogger.log('🔓 [TOKEN GATE] Tokens are now ready, releasing queued requests');
  _isTokensReady = true;
  if (_tokenReadinessCompleter != null && !_tokenReadinessCompleter!.isCompleted) {
    _tokenReadinessCompleter!.complete();
  }
}

void resetTokenGate() {
  AppLogger.log('🔄 [TOKEN GATE] Resetting token gate for new session');
  _isTokensReady = false;
  _tokenReadinessCompleter = Completer<void>();
}

Future<void> waitForTokenReadiness() async {
  if (_isTokensReady) return;
  _tokenReadinessCompleter ??= Completer<void>();

  AppLogger.log('⏳ [TOKEN GATE] Waiting for tokens to be ready...');
  try {
    await _tokenReadinessCompleter!.future.timeout(const Duration(seconds: 3));
  } catch (_) {
    AppLogger.warn('⚠️ [TOKEN GATE] Token readiness timeout, proceeding with request');
    _isTokensReady = true;
  }
}

// Active refresh promise to avoid duplicate concurrent refresh requests
Future<TokenRefreshResult>? _refreshFuture;
bool _isRefreshing = false;

Future<String?> _getFirebaseIdToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  } catch (_) {
    return null;
  }
}

/// Centralized token refresh function — ensures only ONE refresh happens at a time
Future<TokenRefreshResult> performTokenRefresh({String? uid}) async {
  if (_isRefreshing && _refreshFuture != null) {
    AppLogger.log('🔄 [TOKEN SYNC] Refresh already in progress, waiting...');
    return _refreshFuture!;
  }

  AppLogger.log('🔄 [TOKEN SYNC] Starting new token refresh');
  _isRefreshing = true;

  _refreshFuture = () async {
    try {
      final refreshToken = await AppStorage.getRefreshToken();
      final userId = uid ?? await AppStorage.get('uid') as String?;

      if ((refreshToken == null || refreshToken.isEmpty) && userId != null && userId.isNotEmpty) {
        AppLogger.log('🔄 [TOKEN SYNC] No refresh token, generating fresh tokens for user: $userId');
        return await _generateFreshTokensInternal(userId);
      }

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.error('❌ [TOKEN SYNC] No refresh token available');
        return TokenRefreshResult(success: false, isSessionExpired: true);
      }

      AppLogger.log('🔄 [TOKEN SYNC] Refreshing with existing refresh token');
      final res = await Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      )).post('/v1/auth/refresh', data: {'refreshToken': refreshToken});

      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'];
        final accessToken = data['accessToken'] as String;
        final newRefreshToken = (data['refreshToken'] as String?) ?? refreshToken;
        final expiresIn = (data['expiresIn'] as int?) ?? 900;
        final refreshExpiresIn = (data['refreshExpiresIn'] as int?) ?? (30 * 24 * 60 * 60);

        await AppStorage.setAuthTokens(
          accessToken,
          newRefreshToken,
          expiresIn: expiresIn,
          refreshExpiresIn: refreshExpiresIn,
        );
        clearTokenCache();
        dioClient.options.headers['Authorization'] = 'Bearer $accessToken';

        AppLogger.emoji('✅', '[TOKEN SYNC] Tokens refreshed successfully');
        return TokenRefreshResult(
          success: true,
          accessToken: accessToken,
          refreshToken: newRefreshToken,
        );
      }

      throw Exception('Invalid refresh response structure');
    } on DioException catch (e) {
      AppLogger.error('❌ [TOKEN SYNC] Token refresh error:', e);
      final statusCode = e.response?.statusCode;
      final errorCode = e.response?.data?['code'] as String?;
      final errorData = e.response?.data?['data'];

      if (statusCode == 403 && errorCode == 'USER_BANNED') {
        AppLogger.error('🚫 [TOKEN SYNC] User is banned - forcing logout');
        await AppStorage.clear();
        clearTokenCache();
        resetTokenGate();
        _emitForceLogout(
          'user_banned',
          errorData?['banReason'] as String? ?? 'Your account has been banned.',
        );
        return TokenRefreshResult(success: false, isSessionExpired: true);
      }

      if (statusCode == 401) {
        final userId = uid ?? await AppStorage.get('uid') as String?;
        if (userId != null && userId.isNotEmpty) {
          AppLogger.log('🔄 [TOKEN SYNC] Refresh token 401, attempting fresh token generation...');
          return await _generateFreshTokensInternal(userId);
        }
      }

      final isNetwork = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.response == null;

      if (isNetwork) {
        AppLogger.log('⚠️ [TOKEN SYNC] Network error during token refresh - preserving existing tokens');
        return TokenRefreshResult(success: false, isNetworkError: true);
      }

      return TokenRefreshResult(success: false, isSessionExpired: statusCode == 401);
    } catch (e) {
      AppLogger.error('❌ [TOKEN SYNC] Unexpected error during refresh', e);
      return TokenRefreshResult(success: false);
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
    }
  }();

  return _refreshFuture!;
}

Future<TokenRefreshResult> _generateFreshTokensInternal(String userId) async {
  try {
    final firebaseToken = await _getFirebaseIdToken();
    final res = await Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        if (firebaseToken != null && firebaseToken.isNotEmpty)
          'x-firebase-token': firebaseToken,
      },
    )).post('/v1/auth/generate-tokens', data: {'userId': userId});

    if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
      final data = res.data['data'];
      final accessToken = data['accessToken'] as String;
      final newRefreshToken = data['refreshToken'] as String;
      final expiresIn = (data['expiresIn'] as int?) ?? 900;
      final refreshExpiresIn = (data['refreshExpiresIn'] as int?) ?? (30 * 24 * 60 * 60);

      await AppStorage.setAuthTokens(
        accessToken,
        newRefreshToken,
        expiresIn: expiresIn,
        refreshExpiresIn: refreshExpiresIn,
      );
      clearTokenCache();
      dioClient.options.headers['Authorization'] = 'Bearer $accessToken';

      AppLogger.emoji('✅', '[TOKEN SYNC] Fresh tokens generated successfully');
      return TokenRefreshResult(
        success: true,
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
    }
    throw Exception('Invalid generate-tokens response');
  } on DioException catch (e) {
    AppLogger.error('❌ [TOKEN SYNC] Fresh token generation failed', e);
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      AppLogger.error('❌ [TOKEN SYNC] User session is invalid - clearing tokens & forcing logout');
      await AppStorage.clearAuthTokens();
      await AppStorage.remove('uid');
      clearTokenCache();
      resetTokenGate();
      _emitForceLogout('session_expired', 'Your session has expired. Please log in again.');
      return TokenRefreshResult(success: false, isSessionExpired: true);
    }
    final isNetwork = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.response == null;
    return TokenRefreshResult(success: false, isNetworkError: isNetwork);
  } catch (e) {
    return TokenRefreshResult(success: false);
  }
}

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final version = await _getAppBuildNumber();
        options.headers['x-app-version'] = version;

        final skipAuth = [
          '/v1/auth/refresh',
          '/v1/auth/generate-tokens',
          '/v1/user/create',
        ];
        final isSkip = skipAuth.any((p) => options.path.contains(p));

        if (isSkip) {
          return handler.next(options);
        }

        // Wait for token readiness
        await waitForTokenReadiness();

        // Read or check token cache
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_tokenCache.accessToken == null || (now - _tokenCache.cachedAt) >= _tokenCacheTtl) {
          _tokenCache.accessToken = await AppStorage.getAccessToken();
          _tokenCache.refreshToken = await AppStorage.getRefreshToken();
          final expStr = await AppStorage.get('tokenExpiry') as String?;
          _tokenCache.tokenExpiry = expStr != null ? int.tryParse(expStr) : null;
          _tokenCache.cachedAt = now;
        }

        var accessToken = _tokenCache.accessToken;
        final refreshToken = _tokenCache.refreshToken;
        final tokenExpiry = _tokenCache.tokenExpiry;
        final isExpired = tokenExpiry == null || now >= (tokenExpiry - 60000);

        // Proactive token refresh before request if token is expired
        if (isExpired && refreshToken != null && refreshToken.isNotEmpty) {
          AppLogger.log('🔄 [REQUEST INTERCEPTOR] Token expired, refreshing before request...');
          try {
            final result = await performTokenRefresh();
            if (result.success && result.accessToken != null) {
              accessToken = result.accessToken;
              AppLogger.emoji('✅', '[REQUEST INTERCEPTOR] Token refreshed successfully');
            }
          } catch (e) {
            AppLogger.error('❌ [REQUEST INTERCEPTOR] Token refresh error:', e);
          }
        }

        final method = options.method.toLowerCase();
        if (['post', 'put', 'patch', 'delete'].contains(method)) {
          options.headers['X-Request-Id'] = _uuid();
          options.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
        }

        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        } else {
          options.headers.remove('Authorization');
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final errorCode = error.response?.data?['code'] as String?;
        final originalRequest = error.requestOptions;

        // Handle 401 TOKEN_EXPIRED
        if (statusCode == 401 && errorCode == 'TOKEN_EXPIRED') {
          AppLogger.log('🔄 [AXIOS] Token expired response, starting refresh process...');
          try {
            final result = await performTokenRefresh();
            if (result.success && result.accessToken != null) {
              originalRequest.headers['Authorization'] = 'Bearer ${result.accessToken}';
              try {
                final response = await dio.fetch(originalRequest);
                return handler.resolve(response);
              } catch (e) {
                if (e is DioException) return handler.next(e);
                return handler.next(error);
              }
            } else if (result.isNetworkError) {
              // Preserve error, do not clear session on network failure
              return handler.next(error);
            }
          } catch (refreshError) {
            AppLogger.error('❌ [AXIOS] Token refresh failed:', refreshError);
            return handler.next(error);
          }
        }

        // Handle 401 INVALID_TOKEN or TOKEN_REVOKED
        if (statusCode == 401 &&
            (errorCode == 'INVALID_TOKEN' || errorCode == 'TOKEN_REVOKED')) {
          AppLogger.emoji('❌', 'Invalid/Revoked token, clearing auth data and forcing logout');
          await AppStorage.clearAuthTokens();
          await AppStorage.remove('uid');
          clearTokenCache();
          resetTokenGate();
          _emitForceLogout('token_revoked', 'Your session has been invalidated. Please log in again.');
        }

        // Handle 403 USER_BANNED or USER_NOT_ACTIVE
        if (statusCode == 403) {
          final errorData = error.response?.data?['data'];
          if (errorCode == 'USER_BANNED') {
            AppLogger.log('🚫 User is banned, logging out...');
            await AppStorage.clear();
            clearTokenCache();
            resetTokenGate();
            _emitForceLogout(
              'user_banned',
              errorData?['banReason'] as String? ?? 'Your account has been banned.',
            );
          } else if (errorCode == 'USER_NOT_ACTIVE') {
            AppLogger.log('🚫 User account is not active, logging out...');
            await AppStorage.clear();
            clearTokenCache();
            resetTokenGate();
            _emitForceLogout('user_not_active', 'Your account is inactive.');
          }
        }

        handler.next(error);
      },
    ));
  }

  Future<void> clearAllSession() async {
    await AppStorage.clearAuthTokens();
    await AppStorage.remove('uid');
    clearTokenCache();
    resetTokenGate();
  }
}

final dioClient = DioClient().dio;

