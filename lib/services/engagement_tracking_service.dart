import 'package:shared_preferences/shared_preferences.dart';
import '../analytics/analytics_service.dart';
import '../utils/logger.dart';

// Mirrors RN useEngagementTracking.js
// Fires daily_active_user + Daily_Active_User at most once per calendar day.
// Computes consecutive daily streak → engagement_tier.
class EngagementTrackingService {
  static const _keyLastActiveDate = 'analytics_last_active_date';
  static const _keyConsecutiveDays = 'analytics_consecutive_days';

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _engagementTier(int consecutiveDays) {
    if (consecutiveDays >= 14) return 'power';
    if (consecutiveDays >= 7) return 'engaged';
    if (consecutiveDays >= 3) return 'regular';
    return 'casual';
  }

  static Future<void> checkAndTrackDailyOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayString();
      final lastActive = prefs.getString(_keyLastActiveDate) ?? '';

      if (lastActive == today) return; // already tracked today

      // Compute streak: +1 if yesterday, else reset to 1
      int streak = prefs.getInt(_keyConsecutiveDays) ?? 0;
      if (lastActive.isNotEmpty) {
        final last = DateTime.tryParse(lastActive);
        if (last != null) {
          final diff = DateTime.now().difference(last).inDays;
          streak = (diff == 1) ? streak + 1 : 1;
        } else {
          streak = 1;
        }
      } else {
        streak = 1;
      }

      await prefs.setString(_keyLastActiveDate, today);
      await prefs.setInt(_keyConsecutiveDays, streak);

      final tier = _engagementTier(streak);
      await AnalyticsService.logDailyActiveUser(
        consecutiveDays: streak,
        engagementTier: tier,
      );
      AppLogger.log('[Engagement] daily_active_user streak=$streak tier=$tier');
    } catch (e) {
      AppLogger.error('[Engagement] checkAndTrackDailyOpen error', e);
    }
  }

  static Future<int> getConsecutiveDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyConsecutiveDays) ?? 0;
  }

  static Future<String> getEngagementTier() async {
    final days = await getConsecutiveDays();
    return _engagementTier(days);
  }
}
