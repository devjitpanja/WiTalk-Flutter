import '../api/dio_client.dart';
import '../api/app_endpoints.dart';
import '../utils/logger.dart';

/// Ghost mode duration options — mirrors RN GhostModeModal options.
enum GhostModeDuration {
  threeHours(3),
  twentyFourHours(24),
  indefinite(null);

  final int? hours;
  const GhostModeDuration(this.hours);
}

/// Result of a ghost mode operation.
class GhostModeResult {
  final bool success;
  final bool? enabled;
  final String? error;

  const GhostModeResult({required this.success, this.enabled, this.error});
}

/// Service for ghost mode (location privacy) — mirrors RN ghostModeService.js.
///
/// Ghost mode hides the user from the nearby-people map for the selected duration.
/// Works identically on Android and iOS — no platform-specific code required.
class GhostModeService {
  /// Enable ghost mode for [uid] with [duration].
  static Future<GhostModeResult> enableGhostMode(
    String uid,
    GhostModeDuration duration,
  ) async {
    try {
      final res = await dioClient.put(
        AppEndpoints.ghostMode(uid),
        data: {
          'enabled': true,
          if (duration.hours != null) 'durationHours': duration.hours,
        },
      );
      final success = res.data?['success'] == true;
      AppLogger.log('[GhostMode] Enabled (${duration.hours ?? 'indefinite'}h): $success');
      return GhostModeResult(success: success, enabled: success ? true : null);
    } catch (e) {
      AppLogger.error('[GhostMode] enableGhostMode failed', e);
      return GhostModeResult(success: false, error: e.toString());
    }
  }

  /// Disable ghost mode for [uid].
  static Future<GhostModeResult> disableGhostMode(String uid) async {
    try {
      final res = await dioClient.put(
        AppEndpoints.ghostMode(uid),
        data: {'enabled': false},
      );
      final success = res.data?['success'] == true;
      AppLogger.log('[GhostMode] Disabled: $success');
      return GhostModeResult(success: success, enabled: success ? false : null);
    } catch (e) {
      AppLogger.error('[GhostMode] disableGhostMode failed', e);
      return GhostModeResult(success: false, error: e.toString());
    }
  }

  /// Fetch current ghost mode status for [uid].
  static Future<GhostModeResult> getStatus(String uid) async {
    try {
      final res = await dioClient.get(AppEndpoints.ghostMode(uid));
      final data = res.data?['data'];
      final enabled = data?['ghost_mode_enabled'] as bool? ?? false;
      return GhostModeResult(success: true, enabled: enabled);
    } catch (e) {
      AppLogger.warn('[GhostMode] getStatus failed: $e');
      return GhostModeResult(success: false, enabled: false);
    }
  }
}
