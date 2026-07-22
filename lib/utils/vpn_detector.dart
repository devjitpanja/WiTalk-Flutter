import 'dart:io';
import 'logger.dart';

/// VPN / emulator / Frida detection.
///
/// Full native detection (matching the RN VpnDetector module) requires a
/// platform channel bridge to Android native code. Until that bridge is wired,
/// these methods use best-effort Dart-level checks that work on both platforms.
///
/// To add native Android detection, implement a MethodChannel in
/// MainActivity.kt that calls the VpnDetector native module from the RN project.
class VpnDetector {
  /// Detect if a VPN interface is active.
  /// On Android/iOS, checks for known VPN-related network interfaces.
  static Future<bool> detectVPN() async {
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false);
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        // Common VPN interface name patterns
        if (name.startsWith('tun') ||
            name.startsWith('tap') ||
            name.startsWith('ppp') ||
            name.startsWith('ipsec') ||
            name.startsWith('vpn') ||
            name == 'utun0' ||
            name == 'utun1' ||
            name == 'utun2') {
          AppLogger.warn('[VpnDetector] VPN interface detected: ${iface.name}');
          return true;
        }
      }
      return false;
    } catch (e) {
      AppLogger.error('[VpnDetector] detectVPN error', e);
      return false;
    }
  }

  /// Detect advanced emulator. Returns false on real devices.
  /// Native-level detection (QEMU fingerprint, hardware sensor checks)
  /// requires the platform channel bridge.
  static Future<bool> detectAdvancedEmulator() async {
    try {
      if (!Platform.isAndroid) return false;
      // Basic check: read build properties via dart:io is not possible.
      // The native bridge is needed for proper emulator fingerprinting.
      return false;
    } catch (e) {
      AppLogger.error('[VpnDetector] detectAdvancedEmulator error', e);
      return false;
    }
  }

  /// Detect Frida / Xposed hooks. Always false without native bridge.
  static Future<bool> detectFrida() async {
    try {
      // Requires native inspection of /proc/self/maps and port 27042 scan.
      // Wire up the platform channel bridge for real detection.
      return false;
    } catch (e) {
      AppLogger.error('[VpnDetector] detectFrida error', e);
      return false;
    }
  }
}
