import 'package:shared_preferences/shared_preferences.dart';
import '../analytics/analytics_service.dart';
import '../analytics/firebase_events.dart';
import '../utils/logger.dart';

// Mirrors RN useChurnTracking.js
// Computes a churn score 0–100 from behavioral signals.
// Fires tier-transition events only — not on every recompute.
// Sets churn_risk_tier Firebase user property on every recompute.
class ChurnTrackingService {
  // ── SharedPreferences keys ────────────────────────────────────────────────────
  static const _keyInactivityDays = 'churn_inactivity_days';
  static const _keySilentExitCount = 'churn_silent_exit_count';
  static const _keyFastExitCount = 'churn_fast_exit_count';
  static const _keyNoFriends = 'churn_no_friends';
  static const _keyNoSpeaking = 'churn_no_speaking';
  static const _keyRetentionDecay = 'churn_retention_decay';
  static const _keyLastChurnTier = 'churn_last_tier';
  static const _keyHighRiskEnteredAt = 'churn_high_risk_entered_at';

  // ── Tier labels ───────────────────────────────────────────────────────────────
  static const tierHealthy = 'healthy';
  static const tierAtRisk = 'at_risk';
  static const tierHigh = 'high_risk';
  static const tierCritical = 'critical';

  static String _scoreToTier(int score) {
    if (score < 30) return tierHealthy;
    if (score < 55) return tierAtRisk;
    if (score < 80) return tierHigh;
    return tierCritical;
  }

  /// Write per-session behavioral signals after leaving a room.
  static Future<void> writeSessionSignals({
    required bool wasOnStage,
    required bool fastExit,       // left in < 60 seconds
    required bool silentExit,     // never spoke
    required bool hasFriends,
    required bool didSpeak,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (silentExit) {
        await prefs.setInt(
            _keySilentExitCount, (prefs.getInt(_keySilentExitCount) ?? 0) + 1);
      }
      if (fastExit) {
        await prefs.setInt(
            _keyFastExitCount, (prefs.getInt(_keyFastExitCount) ?? 0) + 1);
      }
      await prefs.setBool(_keyNoFriends, !hasFriends);
      await prefs.setBool(_keyNoSpeaking, !didSpeak);
    } catch (e) {
      AppLogger.error('[Churn] writeSessionSignals error', e);
    }
  }

  /// Recompute churn score, update Firebase user property, and fire tier events.
  static Future<void> recomputeChurnRisk(String trigger) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final inactivityDays = prefs.getInt(_keyInactivityDays) ?? 0;
      final silentExits = prefs.getInt(_keySilentExitCount) ?? 0;
      final fastExits = prefs.getInt(_keyFastExitCount) ?? 0;
      final noFriends = prefs.getBool(_keyNoFriends) ?? false;
      final noSpeaking = prefs.getBool(_keyNoSpeaking) ?? false;
      final retentionDecay = prefs.getBool(_keyRetentionDecay) ?? false;

      // Score formula mirrors RN (0–100)
      int score = 0;
      score += (inactivityDays * 5).clamp(0, 30);
      score += (silentExits * 3).clamp(0, 20);
      score += (fastExits * 2).clamp(0, 15);
      if (noFriends) score += 15;
      if (noSpeaking) score += 10;
      if (retentionDecay) score += 10;
      score = score.clamp(0, 100);

      final newTier = _scoreToTier(score);
      final lastTier = prefs.getString(_keyLastChurnTier) ?? tierHealthy;

      // Set Firebase user property on every recompute
      await FirebaseEvents.setUserProperty('churn_risk_tier', newTier);

      if (newTier == lastTier) return;

      // Tier worsened
      final tierRank = {tierHealthy: 0, tierAtRisk: 1, tierHigh: 2, tierCritical: 3};
      final rankNew = tierRank[newTier] ?? 0;
      final rankOld = tierRank[lastTier] ?? 0;

      if (rankNew > rankOld) {
        await AnalyticsService.logChurnRiskIncreased(
          fromTier: lastTier,
          toTier: newTier,
          churnScore: score,
          trigger: trigger,
        );

        if ((newTier == tierHigh || newTier == tierCritical) &&
            rankOld < tierRank[tierHigh]!) {
          await AnalyticsService.logUserEnteredHighRiskState(
            churnScore: score,
            trigger: trigger,
          );
          await prefs.setString(
              _keyHighRiskEnteredAt, DateTime.now().toIso8601String());
        }
      } else if (rankNew < rankOld &&
          (lastTier == tierHigh || lastTier == tierCritical)) {
        // Recovery
        final enteredStr = prefs.getString(_keyHighRiskEnteredAt);
        final enteredAt =
            enteredStr != null ? DateTime.tryParse(enteredStr) : null;
        final daysAtRisk =
            enteredAt != null ? DateTime.now().difference(enteredAt).inDays : 0;
        await AnalyticsService.logUserRecoveredFromHighRisk(
          churnScore: score,
          daysAtRisk: daysAtRisk,
        );
        await prefs.remove(_keyHighRiskEnteredAt);
      }

      await prefs.setString(_keyLastChurnTier, newTier);
    } catch (e) {
      AppLogger.error('[Churn] recomputeChurnRisk error', e);
    }
  }

  /// Build the payload for account deletion events (mirrors RN buildDeletionPayload).
  static Future<Map<String, dynamic>> buildDeletionPayload(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signupStr = prefs.getString('analytics_signup_date');
      final signup = signupStr != null ? DateTime.tryParse(signupStr) : null;
      final daysSinceSignup =
          signup != null ? DateTime.now().difference(signup).inDays : 0;
      final streak = prefs.getInt('analytics_consecutive_days') ?? 0;
      final tier = prefs.getString(_keyLastChurnTier) ?? tierHealthy;

      return {
        'user_id': userId,
        'user_quality_tier': tier,
        'days_since_signup': daysSinceSignup,
        'current_streak': streak,
        'silent_room_exit_count': prefs.getInt(_keySilentExitCount) ?? 0,
        'fast_exit_count': prefs.getInt(_keyFastExitCount) ?? 0,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getChurnSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'churn_risk_tier': prefs.getString(_keyLastChurnTier) ?? tierHealthy,
      'silent_room_exit_count': prefs.getInt(_keySilentExitCount) ?? 0,
      'fast_exit_count': prefs.getInt(_keyFastExitCount) ?? 0,
    };
  }

  static Future<void> markInactivityDay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _keyInactivityDays, (prefs.getInt(_keyInactivityDays) ?? 0) + 1);
  }

  static Future<void> resetInactivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyInactivityDays, 0);
  }
}
