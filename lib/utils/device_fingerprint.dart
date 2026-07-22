import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'logger.dart';

final _deviceInfoPlugin = DeviceInfoPlugin();

Future<Map<String, dynamic>> getDeviceInfo() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();

    if (Platform.isAndroid) {
      final info = await _deviceInfoPlugin.androidInfo;
      return {
        'deviceId': info.id,
        'brand': info.brand,
        'model': info.model,
        'osVersion': info.version.release,
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'uniqueId': info.id,
        'platform': 'android',
      };
    } else if (Platform.isIOS) {
      final info = await _deviceInfoPlugin.iosInfo;
      return {
        'deviceId': info.identifierForVendor ?? '',
        'brand': 'Apple',
        'model': info.model,
        'osVersion': info.systemVersion,
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'uniqueId': info.identifierForVendor ?? '',
        'platform': 'ios',
      };
    }
    throw UnsupportedError('Unsupported platform');
  } catch (e) {
    AppLogger.error('Error getting device info', e);
    rethrow;
  }
}

/// On Android, the install referrer is read via a platform channel bridge.
/// On iOS this is not available — returns null.
///
/// To implement the Android side, wire up a MethodChannel in MainActivity.kt
/// that calls the Play Install Referrer library.
Future<Map<String, dynamic>?> getInstallReferrer() async {
  if (!Platform.isAndroid) {
    AppLogger.log('Install Referrer API only available on Android');
    return null;
  }
  // Native bridge not yet implemented — return empty referrer.
  // Wire up MethodChannel('com.witalk/install_referrer') in MainActivity.kt
  // to call InstallReferrerClient when the bridge is ready.
  return {
    'installReferrer': '',
    'referrerClickTimestamp': 0,
    'installBeginTimestamp': 0,
    'installVersion': '',
    'googlePlayInstant': false,
  };
}

Future<Map<String, dynamic>> getDeviceFingerprint() async {
  try {
    final deviceInfo = await getDeviceInfo();
    final installReferrer = await getInstallReferrer();

    return {
      'deviceId': deviceInfo['uniqueId'],
      'brand': deviceInfo['brand'],
      'model': deviceInfo['model'],
      'osVersion': deviceInfo['osVersion'],
      'appVersion': deviceInfo['appVersion'],
      'installReferrer': installReferrer?['installReferrer'] ?? '',
      'referrerClickTimestamp': installReferrer?['referrerClickTimestamp'] ?? 0,
      'installBeginTimestamp': installReferrer?['installBeginTimestamp'] ?? 0,
      'installVersion': installReferrer?['installVersion'] ?? deviceInfo['appVersion'],
      'googlePlayInstant': installReferrer?['googlePlayInstant'] ?? false,
    };
  } catch (e) {
    AppLogger.error('Error creating device fingerprint', e);
    rethrow;
  }
}

/// Parses a referral code from an install referrer string.
/// Format: "referral_code=USER1234&utm_source=app"
String? extractReferralCodeFromInstallReferrer(String? installReferrer) {
  if (installReferrer == null || installReferrer.isEmpty) return null;
  try {
    final uri = Uri(query: installReferrer);
    final code = uri.queryParameters['referral_code'] ?? uri.queryParameters['ref'];
    return code?.toUpperCase();
  } catch (e) {
    AppLogger.error('Error extracting referral code', e);
    return null;
  }
}
