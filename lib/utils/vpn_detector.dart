import 'package:flutter/services.dart';
import 'logger.dart';

const _channel = MethodChannel('com.witalk/vpn_detector');

/// VPN / emulator / Frida detection via platform channel.
///
/// Android: 9-layer detection (file paths, build props, packages, sensors, storage).
/// iOS: VPN via interface names, simulator check, Frida via port + dylib scan.
class VpnDetector {
  /// Returns true if a VPN interface is active.
  static Future<bool> detectVPN() async {
    try {
      return await _channel.invokeMethod<bool>('isVpnActive') ?? false;
    } catch (e) {
      AppLogger.error('[VpnDetector] detectVPN error', e);
      return false;
    }
  }

  /// Returns true if running in an advanced emulator / simulator.
  static Future<bool> detectAdvancedEmulator() async {
    try {
      return await _channel.invokeMethod<bool>('isAdvancedEmulator') ?? false;
    } catch (e) {
      AppLogger.error('[VpnDetector] detectAdvancedEmulator error', e);
      return false;
    }
  }

  /// Returns true if Frida / Xposed hooking is detected.
  static Future<bool> detectFrida() async {
    try {
      return await _channel.invokeMethod<bool>('isFridaDetected') ?? false;
    } catch (e) {
      AppLogger.error('[VpnDetector] detectFrida error', e);
      return false;
    }
  }
}
