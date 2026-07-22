import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';

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
  return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
}

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingQueue = [];

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
        final skipAuth = ['/v1/auth/refresh', '/v1/auth/generate-tokens', '/v1/user/create'];
        if (!skipAuth.any((p) => options.path.startsWith(p))) {
          final token = await _storage.read(key: 'accessToken');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }
        final method = options.method.toLowerCase();
        if (['post', 'put', 'patch', 'delete'].contains(method)) {
          options.headers['X-Request-Id'] = _uuid();
          options.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final errorCode = error.response?.data?['code'] as String?;

        if (statusCode == 401 && errorCode == 'TOKEN_EXPIRED') {
          if (_isRefreshing) {
            // Queue this request — will be retried after current refresh completes
            _pendingQueue.add(_PendingRequest(error.requestOptions, handler));
            return;
          }
          _isRefreshing = true;
          final refreshed = await _performTokenRefresh();
          _isRefreshing = false;

          if (refreshed) {
            final token = await _storage.read(key: 'accessToken');
            // Retry all queued requests
            for (final pending in _pendingQueue) {
              pending.options.headers['Authorization'] = 'Bearer $token';
              try {
                final res = await dio.fetch(pending.options);
                pending.handler.resolve(res);
              } catch (e) {
                pending.handler.next(error);
              }
            }
            _pendingQueue.clear();
            // Retry the original request
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          } else {
            _pendingQueue.clear();
            await _clearTokens();
            handler.next(error);
          }
          return;
        }

        if (statusCode == 401 &&
            (errorCode == 'INVALID_TOKEN' || errorCode == 'TOKEN_REVOKED')) {
          await _clearTokens();
        }

        handler.next(error);
      },
    ));
  }

  Future<bool> _performTokenRefresh() async {
    try {
      final refreshToken = await _storage.read(key: 'refreshToken');
      if (refreshToken == null) return await _generateTokens();

      final res = await Dio().post(
        '${AppConfig.apiBaseUrl}/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data['data'];
      await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
      await _storage.write(key: 'refreshToken', value: data['refreshToken'] as String);
      if (data['expiresIn'] != null) {
        final expiry = DateTime.now().millisecondsSinceEpoch + (data['expiresIn'] as int) * 1000;
        await _storage.write(key: 'tokenExpiry', value: expiry.toString());
      }
      return true;
    } catch (e) {
      return await _generateTokens();
    }
  }

  Future<bool> _generateTokens() async {
    try {
      final uid = await _storage.read(key: 'uid');
      if (uid == null) return false;
      final res = await Dio().post(
        '${AppConfig.apiBaseUrl}/v1/auth/generate-tokens',
        data: {'userId': uid},
      );
      final data = res.data['data'];
      await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
      await _storage.write(key: 'refreshToken', value: data['refreshToken'] as String);
      if (data['expiresIn'] != null) {
        final expiry = DateTime.now().millisecondsSinceEpoch + (data['expiresIn'] as int) * 1000;
        await _storage.write(key: 'tokenExpiry', value: expiry.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    await Future.wait([
      _storage.delete(key: 'accessToken'),
      _storage.delete(key: 'refreshToken'),
      _storage.delete(key: 'tokenExpiry'),
    ]);
  }

  Future<void> clearAllSession() async {
    await Future.wait([
      _storage.delete(key: 'accessToken'),
      _storage.delete(key: 'refreshToken'),
      _storage.delete(key: 'tokenExpiry'),
      _storage.delete(key: 'uid'),
    ]);
  }
}

class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.options, this.handler);
}

final dioClient = DioClient().dio;
