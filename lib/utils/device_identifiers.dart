import 'dart:io';
import 'package:flutter/services.dart';
import 'logger.dart';

const _channel = MethodChannel('com.witalk/device_identifiers');

/// Advertising info result.
class AdvertisingInfo {
  /// Google Advertising ID (Android) / IDFA (iOS). Empty if not available or user opted out.
  final String gaid;
  final bool isLimitAdTracking;
  final bool isAdIdDeleted;
  /// iOS only: identifierForVendor. Empty on Android.
  final String idfv;

  const AdvertisingInfo({
    this.gaid = '',
    this.isLimitAdTracking = false,
    this.isAdIdDeleted = false,
    this.idfv = '',
  });
}

/// Widevine DRM info (Android only).
class WidevineInfo {
  /// "L1", "L2", "L3", "unknown", or "not_available_ios"
  final String securityLevel;
  final String deviceId;

  const WidevineInfo({this.securityLevel = 'unknown', this.deviceId = ''});
}

/// Returns advertising ID info.
///
/// Android : GAID via Google Play Services. Respects Limit Ad Tracking flag.
/// iOS     : IDFA via ASIdentifierManager. Requests ATT permission if needed (iOS 14+).
///           Also returns IDFV as a stable fallback identifier.
///
/// Always soft-fails — never throws.
Future<AdvertisingInfo> getAdvertisingInfo() async {
  try {
    final result = await _channel.invokeMapMethod<String, dynamic>('getAdvertisingInfo');
    if (result == null) return const AdvertisingInfo();
    return AdvertisingInfo(
      gaid: result['gaid'] as String? ?? '',
      isLimitAdTracking: result['isLimitAdTracking'] as bool? ?? false,
      isAdIdDeleted: result['isAdIdDeleted'] as bool? ?? false,
      idfv: result['idfv'] as String? ?? '',
    );
  } on MissingPluginException {
    return const AdvertisingInfo();
  } catch (e) {
    AppLogger.warn('[DeviceIdentifiers] getAdvertisingInfo failed: $e');
    return const AdvertisingInfo();
  }
}

/// Returns the device's stable unique identifier.
///
/// Android : ANDROID_ID (unique per device + signing certificate, resets on factory reset).
/// iOS     : identifierForVendor (IDFV) — stable per app-vendor pair.
Future<String> getAndroidId() async {
  try {
    return await _channel.invokeMethod<String>('getAndroidId') ?? '';
  } on MissingPluginException {
    return '';
  } catch (e) {
    AppLogger.warn('[DeviceIdentifiers] getAndroidId failed: $e');
    return '';
  }
}

/// Returns Widevine DRM information.
///
/// Android : L1/L2/L3 security level + device ID.
/// iOS     : Returns WidevineInfo(securityLevel: 'not_available_ios', deviceId: '').
///           iOS uses FairPlay, which does not expose a public device ID.
Future<WidevineInfo> getWidevineInfo() async {
  try {
    final result = await _channel.invokeMapMethod<String, dynamic>('getWidevineInfo');
    if (result == null) return const WidevineInfo();
    return WidevineInfo(
      securityLevel: result['securityLevel'] as String? ?? 'unknown',
      deviceId: result['deviceId'] as String? ?? '',
    );
  } on MissingPluginException {
    return const WidevineInfo();
  } catch (e) {
    AppLogger.warn('[DeviceIdentifiers] getWidevineInfo failed: $e');
    return const WidevineInfo();
  }
}

/// Collects all device identifiers in parallel for use in ban checks.
Future<Map<String, dynamic>> collectDeviceIdentifiers() async {
  final results = await Future.wait([
    getAdvertisingInfo(),
    getAndroidId(),
    getWidevineInfo(),
  ]);

  final adInfo = results[0] as AdvertisingInfo;
  final androidId = results[1] as String;
  final widevine = results[2] as WidevineInfo;

  return {
    'gaid': adInfo.gaid,
    'isLimitAdTracking': adInfo.isLimitAdTracking,
    'isAdIdDeleted': adInfo.isAdIdDeleted,
    'idfv': adInfo.idfv,
    'androidId': androidId,
    'widevineSecurityLevel': widevine.securityLevel,
    'widevineDeviceId': widevine.deviceId,
    'platform': Platform.isIOS ? 'ios' : 'android',
  };
}
