import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api/dio_client.dart';
import '../api/app_endpoints.dart';
import '../config/app_config.dart';
import '../utils/storage.dart';
import '../utils/device_fingerprint.dart';
import '../utils/ip_location.dart';
import '../utils/security_profile.dart';
import '../utils/app_integrity.dart';
import '../utils/device_identifiers.dart';
import '../utils/logger.dart';
import 'ban_check_service.dart';
import 'dart:io';

const _webClientId = AppConfig.googleWebClientId;

class AuthResult {
  final bool success;
  final String? uid;
  final String? nextRoute;
  final String? error;

  const AuthResult({
    required this.success,
    this.uid,
    this.nextRoute,
    this.error,
  });
}

// Cache for pre-fetched ISP data — filled at app open, used at sign-in time
_IspCache? _ispCache;
_DeviceBanCache? _deviceBanCache;

class _IspCache {
  final String? ip;
  final String? isp;
  final String? userType;
  final String? asn;
  final List<dynamic> blockedList;
  final bool lookupSuccess;
  final bool blockedListSuccess;
  final int fetchedAt;

  _IspCache({
    this.ip,
    this.isp,
    this.userType,
    this.asn,
    this.blockedList = const [],
    this.lookupSuccess = false,
    this.blockedListSuccess = false,
    required this.fetchedAt,
  });

  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - fetchedAt > 10 * 60 * 1000;
}

class _DeviceBanCache {
  final BanResult result;
  final int fetchedAt;

  _DeviceBanCache({required this.result, required this.fetchedAt});

  static const _ttl = 2 * 60 * 1000; // 2 minutes

  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - fetchedAt > _ttl;
}

/// Prefetch ISP and device ban data in the background so sign-in is instant.
/// Called from main.dart on app open. Fire-and-forget.
Future<void> prefetchAuthSecurityData() async {
  await Future.wait([
    _prefetchIspData(),
    _prefetchDeviceBan(),
  ]);
}

Future<void> _prefetchIspData() async {
  try {
    final ip = await getPublicIP();
    final results = await Future.wait([
      _fetchIpLookup(ip),
      _fetchBlockedIsps(),
    ]);
    final lookup = results[0] as Map<String, dynamic>?;
    final blockedIsps = results[1] as List<dynamic>;

    _ispCache = _IspCache(
      ip: ip,
      isp: lookup?['traits']?['isp'] as String?,
      userType: lookup?['traits']?['user_type'] as String?,
      asn: lookup?['traits']?['autonomous_system_number']?.toString(),
      blockedList: blockedIsps,
      lookupSuccess: lookup != null,
      blockedListSuccess: true,
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
    );
    AppLogger.log('[AuthService] ISP prefetch complete (type=${_ispCache!.userType})');
  } catch (e) {
    AppLogger.warn('[AuthService] ISP prefetch failed: $e');
    _ispCache = _IspCache(fetchedAt: DateTime.now().millisecondsSinceEpoch);
  }
}

Future<Map<String, dynamic>?> _fetchIpLookup(String? ip) async {
  try {
    final res = await dioClient.get('${AppEndpoints.ipLookup}?ip=${ip ?? ''}');
    return res.data?['data'] as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

Future<List<dynamic>> _fetchBlockedIsps() async {
  try {
    final res = await dioClient.get(AppEndpoints.blockedIsps);
    return res.data?['data'] as List<dynamic>? ?? [];
  } catch (_) {
    return [];
  }
}

Future<void> _prefetchDeviceBan() async {
  try {
    final result = await BanCheckService.checkAllDeviceBans();
    _deviceBanCache = _DeviceBanCache(
      result: result,
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
    );
    AppLogger.log('[AuthService] Device ban prefetch: isBanned=${result.isBanned}');
  } catch (e) {
    AppLogger.warn('[AuthService] Device ban prefetch failed: $e');
  }
}

class AuthService {
  static final _googleSignIn = GoogleSignIn(serverClientId: _webClientId);
  static final _firebaseAuth = FirebaseAuth.instance;

  static Future<AuthResult> signInWithGoogle() async {
    try {
      // ── Step 1: Pre-login device ban check ────────────────────────────────
      BanResult deviceBan;
      if (_deviceBanCache != null && !_deviceBanCache!.isStale) {
        deviceBan = _deviceBanCache!.result;
      } else {
        deviceBan = await BanCheckService.checkAllDeviceBans();
        _deviceBanCache = _DeviceBanCache(
          result: deviceBan,
          fetchedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
      if (deviceBan.isBanned) {
        return AuthResult(
          success: false,
          error: 'deviceBanned:${deviceBan.banReason ?? 'Your device has been banned.'}',
        );
      }

      // ── Step 2: ISP / network check ────────────────────────────────────────
      if (_ispCache == null || _ispCache!.isStale) {
        await _prefetchIspData();
      }
      final isp = _ispCache;
      if (isp != null && isp.lookupSuccess) {
        if (isp.userType == 'hosting' || isp.userType == 'datacenter') {
          return const AuthResult(
            success: false,
            error: 'networkBlocked:Unauthorized network detected. Please disable any VPN or proxy and try again.',
          );
        }
        if (isp.blockedListSuccess && isp.blockedList.isNotEmpty) {
          for (final entry in isp.blockedList) {
            final blockedAsn = entry['asn']?.toString();
            final blockedIspName = entry['isp']?.toString()?.toLowerCase();
            if (blockedAsn != null && isp.asn == blockedAsn) {
              return const AuthResult(
                success: false,
                error: 'networkBlocked:Your network provider is not allowed.',
              );
            }
            if (blockedIspName != null &&
                isp.isp != null &&
                isp.isp!.toLowerCase().contains(blockedIspName)) {
              return const AuthResult(
                success: false,
                error: 'networkBlocked:Your network provider is not allowed.',
              );
            }
          }
        }
      }

      // ── Step 3: Google Sign-In ─────────────────────────────────────────────
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return const AuthResult(success: false, error: 'cancelled');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user!;

      // ── Step 4: Collect device info + identifiers ─────────────────────────
      final deviceData = await getDeviceInfo();
      final deviceIds = await collectDeviceIdentifiers();

      final userPayload = <String, dynamic>{
        'id': user.uid,
        'name': user.displayName ?? user.email?.split('@').first ?? '',
        'email': user.email,
        'profile_pic': user.photoURL,
        'deviceInfo': deviceData,
        if ((deviceIds['gaid'] as String? ?? '').isNotEmpty)
          'gaid': deviceIds['gaid'],
        if ((deviceIds['widevineDeviceId'] as String? ?? '').isNotEmpty &&
            deviceIds['widevineDeviceId'] != 'not_available_ios')
          'widevineDeviceId': deviceIds['widevineDeviceId'],
        if ((deviceIds['idfv'] as String? ?? '').isNotEmpty)
          'idfv': deviceIds['idfv'],
      };

      // ── Step 5: App integrity (Android: Play Integrity; iOS: App Attest) ──
      final integrity = await requestIntegrityToken(userId: user.uid);
      if (integrity.success) {
        userPayload['integrityToken'] = integrity.token;
        userPayload['integrityNonce'] = integrity.nonce;
        userPayload['integrityMethod'] = integrity.method;
        if (integrity.keyId.isNotEmpty) {
          userPayload['integrityKeyId'] = integrity.keyId;
        }
      }

      // ── Step 6: POST /v1/user/create ──────────────────────────────────────
      final res = await dioClient.post('/v1/user/create', data: userPayload);

      if (res.data['success'] == true || res.data['exists'] == true) {
        // ── Step 7: Generate tokens ─────────────────────────────────────────
        final firebaseIdToken = await user.getIdToken();
        final tokenRes = await Dio().post(
          '${AppConfig.apiBaseUrl}/v1/auth/generate-tokens',
          data: {'userId': user.uid},
          options: Options(headers: {
            'Content-Type': 'application/json',
            'x-firebase-token': firebaseIdToken,
          }),
        );
        final tokens = tokenRes.data['data'];
        if (tokens != null) {
          final accessToken = tokens['accessToken'] as String;
          final refreshToken = tokens['refreshToken'] as String;
          final expiresIn = (tokens['expiresIn'] as int?) ?? 900;
          final refreshExpiresIn =
              (tokens['refreshExpiresIn'] as int?) ?? (30 * 24 * 60 * 60);

          await AppStorage.setAuthTokens(
            accessToken,
            refreshToken,
            expiresIn: expiresIn,
            refreshExpiresIn: refreshExpiresIn,
          );
          // Store UID only in SecureStorage — never in plain SharedPreferences
          await AppStorage.set('uid', user.uid);
          clearTokenCache();
          markTokensAsReady();
        }

        // ── Step 8: Fire-and-forget security profile ───────────────────────
        collectAndSendSecurityProfile(userId: user.uid, updateReason: 'login');

        // ── Step 9: Login status / onboarding ─────────────────────────────
        final statusRes =
            await dioClient.get('/v1/user/${user.uid}/login-status');
        final data = statusRes.data['data'];
        final profile = data['profile'];
        final onboarding = data['onboarding'];
        final ban = data['ban'];

        if (ban['isBanned'] == true) {
          await _clearAuth();
          return AuthResult(
              success: false, error: 'banned:${ban['banReason']}');
        }

        final isProfileComplete = profile['name'] != null &&
            profile['profile_pic'] != null &&
            profile['gender'] != null &&
            profile['city'] != null &&
            profile['birthday'] != null;

        final nextRoute = !isProfileComplete
            ? '/complete-profile'
            : onboarding['isCompleted'] != true
                ? '/purpose-interests'
                : '/home';

        return AuthResult(success: true, uid: user.uid, nextRoute: nextRoute);
      }

      // Handle 403 device banned from /v1/user/create
      final code = res.data?['code'] as String?;
      if (res.statusCode == 403 && code == 'DEVICE_BANNED') {
        return AuthResult(
          success: false,
          error:
              'deviceBanned:${res.data?['data']?['banReason'] ?? 'Your device has been banned.'}',
        );
      }

      return const AuthResult(success: false, error: 'Server error');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } on DioException catch (e) {
      final code = e.response?.data?['code'] as String?;
      if (code == 'DEVICE_BANNED') {
        return AuthResult(
          success: false,
          error:
              'deviceBanned:${e.response?.data?['data']?['banReason'] ?? 'Your device has been banned.'}',
        );
      }
      if (code == 'INTEGRITY_FAILED') {
        return const AuthResult(
          success: false,
          error:
              'integrityFailed:App verification failed. Please use the official WiTalk app.',
        );
      }
      return AuthResult(success: false, error: e.message ?? e.toString());
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  static Future<void> _clearAuth() async {
    await _firebaseAuth.signOut();
    await AppStorage.clear();
    clearTokenCache();
    resetTokenGate();
  }
}
