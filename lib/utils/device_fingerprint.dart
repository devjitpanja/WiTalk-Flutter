import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'logger.dart';

final _deviceInfoPlugin = DeviceInfoPlugin();
const _referrerChannel = MethodChannel('com.witalk/install_referrer');

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

/// Returns Google Play Install Referrer data (Android only).
/// On iOS returns an empty payload — referral codes come via deep link instead.
Future<Map<String, dynamic>?> getInstallReferrer() async {
  try {
    final result = await _referrerChannel.invokeMapMethod<String, dynamic>(
      'getInstallReferrerInfo',
    );
    return result != null ? Map<String, dynamic>.from(result) : null;
  } on PlatformException catch (e) {
    AppLogger.warn('Install Referrer not available: ${e.code}');
    return {
      'installReferrer': '',
      'referrerClickTimestampSeconds': 0.0,
      'installBeginTimestampSeconds': 0.0,
      'installVersion': '',
      'googlePlayInstant': false,
    };
  } catch (e) {
    AppLogger.error('Error getting install referrer', e);
    return null;
  }
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
      'referrerClickTimestampSeconds': installReferrer?['referrerClickTimestampSeconds'] ?? 0.0,
      'installBeginTimestampSeconds': installReferrer?['installBeginTimestampSeconds'] ?? 0.0,
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
