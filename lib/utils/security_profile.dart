import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'vpn_detector.dart';
import 'logger.dart';

final _deviceInfoPlugin = DeviceInfoPlugin();
final _dio = Dio();

Future<T?> _sa<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    AppLogger.warn('[SecurityProfile] sa caught', e);
    return null;
  }
}

/// Collect device and security telemetry and POST to /v1/user/device-security-profile.
/// Fire-and-forget — never throws.
Future<void> collectAndSendSecurityProfile({
  String? userId,
  String updateReason = 'app_open',
  List<String> violations = const [],
}) async {
  try {
    final packageInfo = await _sa(() => PackageInfo.fromPlatform());
    final screen = WidgetsBinding.instance.platformDispatcher.views.first;
    final pixelRatio = screen.devicePixelRatio;

    final Map<String, dynamic> deviceFields = {};

    if (Platform.isAndroid) {
      final info = await _sa(() => _deviceInfoPlugin.androidInfo);
      if (info != null) {
        deviceFields.addAll({
          'brand': info.brand,
          'manufacturer': info.manufacturer,
          'model': info.model,
          'deviceCodename': info.device,
          'product': info.product,
          'hardware': info.hardware,
          'androidVersion': info.version.release,
          'apiLevel': info.version.sdkInt,
          'securityPatch': info.version.securityPatch,
          'buildFingerprint': info.fingerprint,
          'buildTags': info.tags,
          'bootloader': info.bootloader,
          'deviceUniqueId': info.id,
          'isTablet': info.systemFeatures.contains('android.hardware.type.tablet'),
          'isEmulator': !info.isPhysicalDevice,
        });
      }
    } else if (Platform.isIOS) {
      final info = await _sa(() => _deviceInfoPlugin.iosInfo);
      if (info != null) {
        deviceFields.addAll({
          'brand': 'Apple',
          'manufacturer': 'Apple',
          'model': info.model,
          'deviceCodename': info.utsname.machine,
          'product': info.name,
          'androidVersion': info.systemVersion,
          'deviceUniqueId': info.identifierForVendor ?? '',
          'isTablet': info.model.contains('iPad'),
          'isEmulator': !info.isPhysicalDevice,
        });
      }
    }

    final physicalWidth = (screen.physicalSize.width).round();
    final physicalHeight = (screen.physicalSize.height).round();

    // Security checks
    final isVpnActive = await VpnDetector.detectVPN();
    final isAdvancedEmulator = await VpnDetector.detectAdvancedEmulator();
    final isFrida = await VpnDetector.detectFrida();

    final payload = {
      ...deviceFields,
      'userId': userId,
      'appVersion': packageInfo?.version,
      'appBuildNumber': packageInfo?.buildNumber,
      'bundleId': packageInfo?.packageName,
      'screenWidth': physicalWidth,
      'screenHeight': physicalHeight,
      'screenDensity': pixelRatio,
      'isVpn': isVpnActive,
      'isFridaDetected': isFrida,
      'isEmulator': (deviceFields['isEmulator'] ?? false) || isAdvancedEmulator,
      'updateReason': updateReason,
      'securityViolations': violations,
      'platform': Platform.isAndroid ? 'android' : 'ios',
    };

    await _dio.post(
      '${AppConfig.apiBaseUrl}/v1/user/device-security-profile',
      data: payload,
      options: Options(
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
      ),
    );
    AppLogger.log('[SecurityProfile] Sent (reason=$updateReason)');
  } catch (e) {
    AppLogger.warn('[SecurityProfile] Send failed', e);
  }
}
