import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api/dio_client.dart';
import '../config/app_config.dart';
import '../utils/storage.dart';
import '../utils/device_fingerprint.dart';
import '../utils/device_identifiers.dart';
import '../utils/logger.dart';

// Plain unauthenticated Dio for pre-login ban checks — avoids the auth
// interceptor (token gate, force_logout side effects) during login flow.
final _banCheckDio = Dio(BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
  headers: {'Content-Type': 'application/json'},
));

/// Result of a ban check.
class BanResult {
  final bool isBanned;
  final String? banReason;
  final String? banUntil;

  const BanResult({required this.isBanned, this.banReason, this.banUntil});

  static const notBanned = BanResult(isBanned: false);
}

/// Stored ban info surfaced on the auth screen after a forced logout.
class BanInfo {
  final bool banned;
  final String reason;
  final String? banUntil;
  final int timestamp;
  final String? userEmail;
  final String? userName;

  const BanInfo({
    required this.banned,
    required this.reason,
    this.banUntil,
    required this.timestamp,
    this.userEmail,
    this.userName,
  });

  Map<String, dynamic> toJson() => {
        'banned': banned,
        'reason': reason,
        'banUntil': banUntil,
        'timestamp': timestamp,
        'userEmail': userEmail,
        'userName': userName,
      };

  factory BanInfo.fromJson(Map<String, dynamic> j) => BanInfo(
        banned: j['banned'] as bool? ?? true,
        reason: j['reason'] as String? ?? '',
        banUntil: j['banUntil'] as String?,
        timestamp: j['timestamp'] as int? ?? 0,
        userEmail: j['userEmail'] as String?,
        userName: j['userName'] as String?,
      );
}

/// Mirrors RN BanCheckService — handles user ban, device ban, and identifier ban.
class BanCheckService {
  static bool _isHandlingBan = false;

  // Pre-logout callback registered by LiveAudioRoomScreen so it can clean up
  // before the ban logout kicks in.
  static Future<void> Function()? _preLogoutHandler;

  static void registerPreLogoutHandler(Future<void> Function() fn) {
    _preLogoutHandler = fn;
  }

  static void unregisterPreLogoutHandler() {
    _preLogoutHandler = null;
  }

  // ── User ban ────────────────────────────────────────────────────────────────

  /// Check whether [userId] is currently banned via the ban-status endpoint.
  /// Falls back to the user profile endpoint on failure.
  static Future<BanResult> checkBanStatus(String userId) async {
    try {
      final res = await dioClient.get('/v1/user/$userId/ban-status');
      final data = res.data?['data'];
      if (data == null) return BanResult.notBanned;
      final isBanned = data['isBanned'] as bool? ?? false;
      return BanResult(
        isBanned: isBanned,
        banReason: data['banReason'] as String?,
        banUntil: data['banUntil'] as String?,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return const BanResult(isBanned: true, banReason: 'Session invalid');
      }
      // Network error — don't assume banned
      return BanResult.notBanned;
    } catch (_) {
      return BanResult.notBanned;
    }
  }

  /// Full ban handling: run pre-logout hook → sign out → clear storage → store ban info
  /// → emit force_logout event.
  static Future<void> handleBannedUser({
    required String banReason,
    String? banUntil,
  }) async {
    if (_isHandlingBan) return;
    _isHandlingBan = true;

    try {
      // 1. Pre-logout hook (e.g. end live audio room)
      try {
        await _preLogoutHandler?.call();
      } catch (_) {}
      _preLogoutHandler = null;

      // 2. Capture display info before clearing
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      final name = user?.displayName;

      // 3. Sign out
      try {
        final gs = GoogleSignIn();
        if (await gs.isSignedIn()) {
          await gs.signOut();
        }
      } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      // 4. Clear tokens and storage
      clearTokenCache();
      resetTokenGate();

      // 5. Clear all storage, then re-write ban info so it survives the wipe
      await AppStorage.clear();

      final banInfo = BanInfo(
        banned: true,
        reason: banReason,
        banUntil: banUntil,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        userEmail: email,
        userName: name,
      );
      final json = banInfo.toJson();
      await Future.wait(json.entries.map((e) =>
          AppStorage.set('bannedUser_${e.key}', e.value?.toString() ?? '')));

      // 6. Emit force_logout — auth_provider listens and navigates to auth screen
      emitForceLogout('user_banned', banReason);
    } finally {
      _isHandlingBan = false;
    }
  }

  // ── Stored ban info ─────────────────────────────────────────────────────────

  static Future<BanInfo?> getStoredBanInfo() async {
    try {
      final ts = await AppStorage.get('bannedUser_timestamp') as String?;
      if (ts == null || ts.isEmpty) return null;
      final timestamp = int.tryParse(ts) ?? 0;
      // 5-minute TTL
      if (DateTime.now().millisecondsSinceEpoch - timestamp > 5 * 60 * 1000) {
        await clearStoredBanInfo();
        return null;
      }
      final reason = await AppStorage.get('bannedUser_reason') as String? ?? '';
      return BanInfo(
        banned: true,
        reason: reason,
        banUntil: await AppStorage.get('bannedUser_banUntil') as String?,
        timestamp: timestamp,
        userEmail: await AppStorage.get('bannedUser_userEmail') as String?,
        userName: await AppStorage.get('bannedUser_userName') as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearStoredBanInfo() async {
    await Future.wait([
      AppStorage.remove('bannedUser_banned'),
      AppStorage.remove('bannedUser_reason'),
      AppStorage.remove('bannedUser_banUntil'),
      AppStorage.remove('bannedUser_timestamp'),
      AppStorage.remove('bannedUser_userEmail'),
      AppStorage.remove('bannedUser_userName'),
    ]);
  }

  // ── Device ban ──────────────────────────────────────────────────────────────

  /// Check if the current device is banned via device unique ID.
  /// Both Android and iOS: uses device_fingerprint.dart for device ID.
  static Future<BanResult> checkDeviceBan() async {
    try {
      // Collect in parallel — androidId is the real ANDROID_ID (Settings.Secure),
      // matching RN DeviceInfo.getUniqueId() which the server stores bans against.
      final deviceInfo = await getDeviceInfo();
      final deviceIds = await collectDeviceIdentifiers();

      // Use Android ID (ANDROID_ID) as deviceUniqueId — same as RN getUniqueId()
      final androidId = deviceIds['androidId'] as String? ?? '';
      final deviceUniqueId = androidId.isNotEmpty
          ? androidId
          : deviceInfo['deviceId'] as String? ?? '';

      final res = await _banCheckDio.post('/v1/user/check-device-ban', data: {
        'deviceUniqueId': deviceUniqueId,
        'brand': deviceInfo['brand'],
        'model': deviceInfo['model'],
        'platform': deviceInfo['platform'],
      });
      final data = res.data?['data'];
      return BanResult(
        isBanned: data?['isBanned'] as bool? ?? false,
        banReason: data?['banReason'] as String?,
        banUntil: data?['banUntil'] as String?,
      );
    } catch (e) {
      AppLogger.warn('[BanCheckService] checkDeviceBan failed: $e');
      return BanResult.notBanned;
    }
  }

  /// Check if the device is banned via advertising / DRM identifiers.
  ///
  /// Android: GAID (skipped if all-zeros) + Widevine device ID.
  /// iOS: IDFA (if ATT authorized) + IDFV. Widevine is not_available_ios.
  static Future<BanResult> checkIdentifierBan() async {
    try {
      final ids = await collectDeviceIdentifiers();
      final gaid = ids['gaid'] as String? ?? '';
      final widevineId = ids['widevineDeviceId'] as String? ?? '';
      final idfv = ids['idfv'] as String? ?? '';
      final platform = ids['platform'] as String? ?? (Platform.isIOS ? 'ios' : 'android');

      // Skip if no useful identifiers available
      if (gaid.isEmpty && widevineId.isEmpty && idfv.isEmpty) {
        return BanResult.notBanned;
      }

      final payload = <String, dynamic>{
        'platform': platform,
        if (gaid.isNotEmpty) 'gaid': gaid,
        if (widevineId.isNotEmpty && widevineId != 'not_available_ios')
          'widevineDeviceId': widevineId,
        if (idfv.isNotEmpty) 'idfv': idfv,
      };

      final res = await _banCheckDio.post('/v1/user/check-identifier-ban', data: payload);
      final data = res.data?['data'];
      return BanResult(
        isBanned: data?['isBanned'] as bool? ?? false,
        banReason: data?['banReason'] as String?,
        banUntil: data?['banUntil'] as String?,
      );
    } catch (e) {
      AppLogger.warn('[BanCheckService] checkIdentifierBan failed: $e');
      return BanResult.notBanned;
    }
  }

  /// Run device + identifier ban checks in parallel. Returns the first active ban.
  static Future<BanResult> checkAllDeviceBans() async {
    final results = await Future.wait([
      checkDeviceBan(),
      checkIdentifierBan(),
    ]);
    for (final r in results) {
      if (r.isBanned) return r;
    }
    return BanResult.notBanned;
  }

  // ── Ban message helpers ─────────────────────────────────────────────────────

  /// Returns {title, message} for a user account ban — mirrors RN getBanMessage().
  static Map<String, String> getBanMessage(String? banReason, String? banUntil) {
    const title = 'Account Banned';
    final cleaned = _sanitizeReason(banReason) ??
        'Your account has been banned due to violation of our community guidelines.';
    final message = _buildMessage(cleaned, banUntil,
        permanent:
            'This is a permanent ban. If you believe this is a mistake, please contact our support team.');
    return {'title': title, 'message': message};
  }

  /// Returns {title, message} for a device ban — mirrors RN getDeviceBanMessage().
  static Map<String, String> getDeviceBanMessage(String? banReason, String? banUntil) {
    const title = 'Device Banned';
    final cleaned = _sanitizeReason(banReason) ??
        'This device has been banned due to violation of our community guidelines.';
    var message = _buildMessage(cleaned, banUntil,
        permanent:
            'This is a permanent device ban. You cannot create or access any account from this device.');
    message += '\n\nIf you believe this is a mistake, please contact our support team.';
    return {'title': title, 'message': message};
  }

  // Legacy helpers retained for callers that only need one field
  static String getBanTitle(String reason) {
    if (reason.toLowerCase().contains('device')) return 'Device Banned';
    return 'Account Banned';
  }

  static String _buildMessage(String body, String? banUntil, {required String permanent}) {
    if (banUntil != null && banUntil.isNotEmpty) {
      try {
        final until = DateTime.parse(banUntil).toLocal();
        final now = DateTime.now();
        if (until.isAfter(now)) {
          final days = until.difference(now).inDays + 1;
          final formatted = '${until.month}/${until.day}/${until.year}';
          return '$body\n\nThis is a temporary ban that will be lifted on $formatted.\n($days day${days > 1 ? 's' : ''} remaining)';
        } else {
          return '$body\n\nYour ban period has ended. Please contact support if you continue to experience issues.';
        }
      } catch (_) {}
    }
    return '$body\n\n$permanent';
  }

  static String? _sanitizeReason(String? reason) {
    if (reason == null || reason.isEmpty) return null;
    final cleaned = reason.replaceFirst(RegExp(r'^\S+\s+banned:\s*', caseSensitive: false), '').trim();
    return cleaned.isNotEmpty ? cleaned : null;
  }
}

