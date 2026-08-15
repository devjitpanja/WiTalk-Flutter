import 'package:shared_preferences/shared_preferences.dart';
import '../analytics/analytics_service.dart';
import '../utils/logger.dart';

// Mirrors RN useRetentionTracking.js
// Fires D1/D3/D7/D14/D30 and consecutive streak events exactly once
// per app install lifetime. Uses SharedPreferences sentinel keys.
class RetentionTrackingService {
  static const _keySignupDate = 'analytics_signup_date';
  static const _keyFiredD1 = 'analytics_fired_d1';
  static const _keyFiredD3 = 'analytics_fired_d3';
  static const _keyFiredD7 = 'analytics_fired_d7';
  static const _keyFiredD14 = 'analytics_fired_d14';
  static const _keyFiredD30 = 'analytics_fired_d30';
  static const _keyFiredC3 = 'analytics_fired_c3';
  static const _keyFiredC7 = 'analytics_fired_c7';
  static const _keyFiredC14 = 'analytics_fired_c14';

  /// Call once after successful signup / CompleteProfileScreen
  static Future<void> markSignupDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_keySignupDate) != null) return;
      await prefs.setString(_keySignupDate, DateTime.now().toIso8601String());
      AppLogger.log('[Retention] signup date marked');
    } catch (e) {
      AppLogger.error('[Retention] markSignupDate error', e);
    }
  }

  /// Call on every cold start and foreground resume from MainStack equivalent.
  static Future<void> checkRetentionAndStreak({
    required int consecutiveDays,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signupStr = prefs.getString(_keySignupDate);
      if (signupStr == null) return;

      final signup = DateTime.tryParse(signupStr);
      if (signup == null) return;

      final daysSince = DateTime.now().difference(signup).inDays;

      // D1 / D3 / D7 / D14 / D30 — fire once when milestone is first crossed
      if (daysSince >= 1 && prefs.getBool(_keyFiredD1) != true) {
        await prefs.setBool(_keyFiredD1, true);
        await AnalyticsService.logRetentionD1();
        AppLogger.log('[Retention] retention_d1 fired');
      }
      if (daysSince >= 3 && prefs.getBool(_keyFiredD3) != true) {
        await prefs.setBool(_keyFiredD3, true);
        await AnalyticsService.logRetentionD3();
      }
      if (daysSince >= 7 && prefs.getBool(_keyFiredD7) != true) {
        await prefs.setBool(_keyFiredD7, true);
        await AnalyticsService.logRetentionD7();
      }
      if (daysSince >= 14 && prefs.getBool(_keyFiredD14) != true) {
        await prefs.setBool(_keyFiredD14, true);
        await AnalyticsService.logRetentionD14();
      }
      if (daysSince >= 30 && prefs.getBool(_keyFiredD30) != true) {
        await prefs.setBool(_keyFiredD30, true);
        await AnalyticsService.logRetentionD30();
      }

      // Consecutive streak milestones
      if (consecutiveDays >= 3 && prefs.getBool(_keyFiredC3) != true) {
        await prefs.setBool(_keyFiredC3, true);
        await AnalyticsService.logConsecutive3Days();
      }
      if (consecutiveDays >= 7 && prefs.getBool(_keyFiredC7) != true) {
        await prefs.setBool(_keyFiredC7, true);
        await AnalyticsService.logConsecutive7Days();
      }
      if (consecutiveDays >= 14 && prefs.getBool(_keyFiredC14) != true) {
        await prefs.setBool(_keyFiredC14, true);
        await AnalyticsService.logConsecutive14Days();
      }
    } catch (e) {
      AppLogger.error('[Retention] checkRetentionAndStreak error', e);
    }
  }
}
