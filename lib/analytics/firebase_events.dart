import 'package:firebase_analytics/firebase_analytics.dart';
import '../utils/logger.dart';

// Firebase GA4 events — Android & iOS
// Mirrors RN firebaseEvents.js (@react-native-firebase/analytics).
// All errors are swallowed; analytics must never crash the app.
class FirebaseEvents {
  static FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
      AppLogger.log('[Firebase] $name', params);
    } catch (e) {
      AppLogger.error('[Firebase] logEvent error ($name)', e);
    }
  }

  // ── Identity ─────────────────────────────────────────────────────────────────

  static Future<void> setUserId(String id) async {
    try { await _fa.setUserId(id: id); } catch (_) {}
  }

  static Future<void> setUserProperty(String name, String value) async {
    try { await _fa.setUserProperty(name: name, value: value); } catch (_) {}
  }

  static Future<void> setUserProperties(Map<String, String> props) async {
    try {
      await Future.wait(
        props.entries.map((e) => _fa.setUserProperty(name: e.key, value: e.value)),
      );
    } catch (_) {}
  }

  // ── App Open / Session ────────────────────────────────────────────────────────

  static Future<void> logAppOpen() => _log('app_open');

  static Future<void> logSessionStarted({required String userId}) =>
      _log('session_started', {'user_id': userId});

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static Future<void> logSignupStart({String method = 'google'}) =>
      _log('signup_start', {'method': method});

  static Future<void> logSignupComplete({String method = 'google'}) =>
      _log('signup_complete', {'method': method});

  static Future<void> logLogin({String method = 'google'}) async {
    try {
      await _fa.logLogin(loginMethod: method);
    } catch (_) {}
  }

  static Future<void> logSignUp({String method = 'google'}) async {
    try {
      await _fa.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  // ── Content & Feed ────────────────────────────────────────────────────────────

  static Future<void> logFeedViewed() => _log('feed_viewed');

  static Future<void> logFeedMomentPosted({
    required String postType,
    required String mediaType,
  }) =>
      _log('feed_moment_posted', {
        'post_type': postType,
        'media_type': mediaType,
      });

  static Future<void> logSearch({required String searchTerm}) async {
    try {
      await _fa.logSearch(searchTerm: searchTerm);
    } catch (_) {}
  }

  // ── Social ────────────────────────────────────────────────────────────────────

  static Future<void> logFirstMessageSent() => _log('first_message_sent');
  static Future<void> logMutualFriendship() => _log('mutual_friendship');
  static Future<void> logRepeatedUserInteraction() =>
      _log('repeated_user_interaction');
  static Future<void> logReturnedToSameAdda({required String addaId}) =>
      _log('returned_to_same_adda', {'adda_id': addaId});

  // ── Community / Messages ──────────────────────────────────────────────────────

  static Future<void> logCommunityMessageSent({
    required String communityId,
    required String messageType,
  }) =>
      _log('community_message_sent', {
        'community_id': communityId,
        'message_type': messageType,
      });

  static Future<void> logCommunityOpened({required String communityId}) =>
      _log('community_opened', {'community_id': communityId});

  // ── Adda / Audio Rooms ────────────────────────────────────────────────────────

  static Future<void> logJoinAdda({
    required String addaId,
    required String addaTopic,
    required int numberOfUsers,
  }) =>
      _log('join_adda', {
        'adda_id': addaId,
        'adda_topic': addaTopic,
        'number_of_users': numberOfUsers,
      });

  static Future<void> logCreateAdda({String addaTopic = ''}) =>
      _log('create_adda', {'adda_topic': addaTopic});

  static Future<void> logAddaSeatTaken({
    required String addaId,
    required int seatIndex,
    required String addaTopic,
  }) =>
      _log('adda_seat_taken', {
        'adda_id': addaId,
        'seat_index': seatIndex,
        'adda_topic': addaTopic,
      });

  static Future<void> logAddaSpeakerUnmuted({
    required String addaId,
    int? seatIndex,
  }) =>
      _log('adda_speaker_unmuted', {
        'adda_id': addaId,
        if (seatIndex != null) 'seat_index': seatIndex,
      });

  static Future<void> logAddaLeft({
    required String addaId,
    required String addaTopic,
    required int durationSec,
    required int speakingSec,
    required int mutedSec,
    required int silentSec,
    required double speakingPct,
    required int wasOnStage,
    required String userRole,
    required int participantCount,
    required String powerUserTier,
  }) =>
      _log('adda_left', {
        'adda_id': addaId,
        'adda_topic': addaTopic,
        'duration_sec': durationSec,
        'speaking_sec': speakingSec,
        'muted_sec': mutedSec,
        'silent_sec': silentSec,
        'speaking_pct': speakingPct,
        'was_on_stage': wasOnStage,
        'user_role': userRole,
        'participant_count': participantCount,
        'power_user_tier': powerUserTier,
      });

  static Future<void> logAddaStageSession({
    required String addaId,
    required int speakingSec,
    required int mutedSec,
    required double stagePct,
    required double speakingPct,
  }) =>
      _log('adda_stage_session', {
        'adda_id': addaId,
        'speaking_sec': speakingSec,
        'muted_sec': mutedSec,
        'stage_pct': stagePct,
        'speaking_pct': speakingPct,
      });

  // ── Engagement Milestones ─────────────────────────────────────────────────────

  static Future<void> logDailyActiveUser({
    required int consecutiveDays,
    required String engagementTier,
  }) =>
      _log('daily_active_user', {
        'consecutive_days': consecutiveDays,
        'engagement_tier': engagementTier,
      });

  static Future<void> logConversation5Min({
    required String addaId,
    required String addaTopic,
    required int participantCount,
    required String userRole,
  }) =>
      _log('conversation_5min', {
        'adda_id': addaId,
        'adda_topic': addaTopic,
        'participant_count': participantCount,
        'user_role': userRole,
      });

  static Future<void> logConversation15Min({
    required String addaId,
    required String addaTopic,
    required int participantCount,
    required String userRole,
  }) =>
      _log('conversation_15min', {
        'adda_id': addaId,
        'adda_topic': addaTopic,
        'participant_count': participantCount,
        'user_role': userRole,
      });

  static Future<void> logConversation30Min({
    required String addaId,
    required String addaTopic,
    required int participantCount,
    required String userRole,
  }) =>
      _log('conversation_30min', {
        'adda_id': addaId,
        'adda_topic': addaTopic,
        'participant_count': participantCount,
        'user_role': userRole,
      });

  // ── Retention ─────────────────────────────────────────────────────────────────

  static Future<void> logRetentionD1() => _log('retention_d1');
  static Future<void> logRetentionD3() => _log('retention_d3');
  static Future<void> logRetentionD7() => _log('retention_d7');
  static Future<void> logRetentionD14() => _log('retention_d14');
  static Future<void> logRetentionD30() => _log('retention_d30');
  static Future<void> logConsecutive3Days() => _log('consecutive_3_days');
  static Future<void> logConsecutive7Days() => _log('consecutive_7_days');
  static Future<void> logConsecutive14Days() => _log('consecutive_14_days');

  // ── Host Quality Events ───────────────────────────────────────────────────────

  static Future<void> logHosted30MinRoom({
    required String addaId,
    required int durationMin,
  }) =>
      _log('hosted_30min_room', {'adda_id': addaId, 'duration_min': durationMin});

  static Future<void> logRoomWith5Speakers({
    required String addaId,
    required int speakerCount,
  }) =>
      _log('room_with_5_speakers', {'adda_id': addaId, 'speaker_count': speakerCount});

  static Future<void> logHostedActiveRoom({
    required String addaId,
    required int activeSpeakers,
    required int durationMin,
  }) =>
      _log('hosted_active_room', {
        'adda_id': addaId,
        'active_speakers': activeSpeakers,
        'duration_min': durationMin,
      });

  static Future<void> logRoomReopened({required String addaId}) =>
      _log('room_reopened', {'adda_id': addaId});

  // ── User Quality Tier ─────────────────────────────────────────────────────────

  static Future<void> logUserQualityTier({
    required String tier,
    required int score,
  }) =>
      _log('user_quality_tier', {'tier': tier, 'score': score});

  // ── Purchase / Monetization ───────────────────────────────────────────────────

  static Future<void> logBeginCheckout({
    required String communityId,
    required String productId,
    required String productType,
    required double price,
    required String currency,
  }) =>
      _log('begin_checkout', {
        'community_id': communityId,
        'product_id': productId,
        'product_type': productType,
        'value': price,
        'currency': currency,
      });

  static Future<void> logPurchase({
    required String communityId,
    required String communityName,
    required String productId,
    required String productType,
    required double price,
    required String currency,
    required String orderId,
    required String billingPeriod,
    required bool restored,
  }) async {
    try {
      await _fa.logPurchase(
        currency: currency,
        value: price,
        parameters: {
          'community_id': communityId,
          'community_name': communityName,
          'product_id': productId,
          'product_type': productType,
          'order_id': orderId,
          'billing_period': billingPeriod,
          'restored': restored ? 1 : 0,
        },
      );
    } catch (e) {
      AppLogger.error('[Firebase] logPurchase error', e);
    }
  }

  static Future<void> logPurchaseFailed({
    required String communityId,
    required String productId,
    required String errorCode,
  }) =>
      _log('purchase_failed', {
        'community_id': communityId,
        'product_id': productId,
        'error_code': errorCode,
      });

  // ── Account Lifecycle ─────────────────────────────────────────────────────────

  static Future<void> logAccountDeletionStarted(Map<String, Object> payload) =>
      _log('account_deletion_started', payload);

  static Future<void> logAccountDeletionCancelled(Map<String, Object> payload) =>
      _log('account_deletion_cancelled', payload);

  static Future<void> logAccountDeleted(Map<String, Object> payload) =>
      _log('account_deleted', payload);

  // ── Churn Signals ─────────────────────────────────────────────────────────────

  static Future<void> logChurnRiskIncreased({
    required String fromTier,
    required String toTier,
    required int churnScore,
    required String trigger,
  }) =>
      _log('churn_risk_increased', {
        'from_tier': fromTier,
        'to_tier': toTier,
        'churn_score': churnScore,
        'trigger': trigger,
      });

  static Future<void> logUserEnteredHighRiskState({
    required int churnScore,
    required String trigger,
  }) =>
      _log('user_entered_high_risk_state', {
        'churn_score': churnScore,
        'trigger': trigger,
      });

  static Future<void> logUserRecoveredFromHighRisk({
    required int churnScore,
    required int daysAtRisk,
  }) =>
      _log('user_recovered_from_high_risk', {
        'churn_score': churnScore,
        'days_at_risk': daysAtRisk,
      });

  // ── Calls ─────────────────────────────────────────────────────────────────────

  static Future<void> logVoiceCallStarted() => _log('voice_call_started');
  static Future<void> logVideoCallStarted() => _log('video_call_started');
  static Future<void> logRandomChatStarted() => _log('random_chat_started');
}
