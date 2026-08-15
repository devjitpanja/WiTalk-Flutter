import 'package:facebook_app_events/facebook_app_events.dart';
import '../utils/logger.dart';

// Facebook App Events wrapper — Android & iOS
// Mirrors RN metaEvents.js (react-native-fbsdk-next / AppEventsLogger).
// All errors are swallowed so a misconfigured FB SDK never crashes the app.
class MetaEvents {
  static final FacebookAppEvents _fb = FacebookAppEvents();

  static Future<void> _log(String name, [Map<String, dynamic>? params]) async {
    try {
      await _fb.logEvent(name: name, parameters: params);
      AppLogger.log('[Meta] $name', params);
    } catch (e) {
      AppLogger.error('[Meta] logEvent error ($name)', e);
    }
  }

  // ── Identity ─────────────────────────────────────────────────────────────────

  static Future<void> setUserId(String userId) async {
    try {
      await _fb.setUserID(userId);
    } catch (_) {}
  }

  static Future<void> clearUserId() async {
    try {
      await _fb.clearUserID();
    } catch (_) {}
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static Future<void> logSignupStart({String method = 'google'}) =>
      _log('SignupStart', {'fb_registration_method': method});

  static Future<void> logCompleteRegistration({String method = 'google'}) =>
      _log('fb_mobile_complete_registration', {'fb_registration_method': method});

  static Future<void> logSignupComplete({String method = 'google'}) =>
      _log('SignupComplete', {'fb_registration_method': method});

  static Future<void> logLogin({String method = 'google'}) =>
      _log('fb_mobile_login', {'fb_login_method': method});

  // ── Content & Feed ────────────────────────────────────────────────────────────

  static Future<void> logViewContent({
    required String contentType,
    required String contentId,
  }) =>
      _log('fb_mobile_content_view', {
        'fb_content_type': contentType,
        'fb_content_id': contentId,
      });

  static Future<void> logSearch({required String searchString}) =>
      _log('fb_mobile_search', {'fb_search_string': searchString});

  static Future<void> logPostCreated({
    required String postType,
    required String mediaType,
  }) =>
      _log('Feed_Moment_Posted', {
        'post_type': postType,
        'media_type': mediaType,
      });

  // ── Social ────────────────────────────────────────────────────────────────────

  static Future<void> logFollowUser() => _log('FollowUser');
  static Future<void> logInviteSent() => _log('InviteSent');
  static Future<void> logMutualFriendship() => _log('mutual_friendship');

  static Future<void> logFirstMessageSent() => _log('FirstMessageSent');
  static Future<void> logGroupJoined() => _log('GroupJoined');

  // ── Adda / Audio Rooms ────────────────────────────────────────────────────────

  static Future<void> logJoinAdda({
    required String addaId,
    required String addaTopic,
    required int numberOfUsers,
  }) =>
      _log('Join_Adda', {
        'adda_id': addaId,
        'adda_topic': addaTopic,
        'number_of_users': numberOfUsers,
      });

  static Future<void> logCreateAdda({String addaTopic = ''}) =>
      _log('Create_Adda', {'adda_topic': addaTopic});

  static Future<void> logAddaSeatTaken({
    required String addaId,
    required int seatIndex,
    required String addaTopic,
  }) =>
      _log('Adda_Seat_Taken', {
        'adda_id': addaId,
        'seat_index': seatIndex,
        'adda_topic': addaTopic,
      });

  static Future<void> logAddaSpeakerUnmuted({
    required String addaId,
    int? seatIndex,
  }) =>
      _log('Adda_Speaker_Unmuted', {
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
      _log('Adda_Left', {
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

  // ── Engagement Milestones ─────────────────────────────────────────────────────

  static Future<void> logDailyActiveUser({
    required int consecutiveDays,
    required String engagementTier,
  }) =>
      _log('Daily_Active_User', {
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

  static Future<void> logRepeatedUserInteraction() =>
      _log('repeated_user_interaction');

  static Future<void> logReturnedToSameAdda({required String addaId}) =>
      _log('returned_to_same_adda', {'adda_id': addaId});

  // ── User Quality Tier ─────────────────────────────────────────────────────────

  static Future<void> logUserQualityTier({
    required String tier,
    required int score,
  }) =>
      _log('user_quality_tier', {'tier': tier, 'score': score});

  // ── Community / Messages ──────────────────────────────────────────────────────

  static Future<void> logCommunityMessageSent({
    required String communityId,
    required String messageType,
  }) =>
      _log('Community_Message_Sent', {
        'community_id': communityId,
        'message_type': messageType,
      });

  // ── Purchase / Monetization ───────────────────────────────────────────────────

  static Future<void> logInitiateCheckout({
    required String communityId,
    required String productId,
    required String productType,
    required double price,
    required String currency,
  }) =>
      _log('fb_mobile_initiated_checkout', {
        'community_id': communityId,
        'product_id': productId,
        'product_type': productType,
        'fb_num_items': 1,
        'fb_payment_info_available': 0,
        'fb_currency': currency,
        'fb_total_price': price,
      });

  static Future<void> logPurchase({
    required double amount,
    required String currency,
    required Map<String, dynamic> parameters,
  }) async {
    try {
      await _fb.logPurchase(amount: amount, currency: currency, parameters: parameters);
      AppLogger.log('[Meta] Purchase amount=$amount currency=$currency', parameters);
    } catch (e) {
      AppLogger.error('[Meta] logPurchase error', e);
    }
  }

  static Future<void> logSubscriptionStarted({
    required String productId,
    required double price,
    required String currency,
  }) =>
      _log('Subscribe', {
        'product_id': productId,
        'price': price,
        'currency': currency,
      });

  // ── Account Lifecycle ─────────────────────────────────────────────────────────

  static Future<void> logAccountDeletionStarted(Map<String, dynamic> payload) =>
      _log('account_deletion_started', payload);

  static Future<void> logAccountDeletionCancelled(Map<String, dynamic> payload) =>
      _log('account_deletion_cancelled', payload);

  static Future<void> logAccountDeleted(Map<String, dynamic> payload) =>
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

  // ── Ads (IAA) ─────────────────────────────────────────────────────────────────

  static Future<void> logAdImpression({
    required double value,
    String currency = 'USD',
  }) async {
    try {
      await _fb.logPurchase(
        amount: value,
        currency: currency,
        parameters: {'fb_ad_type': 'rewarded'},
      );
      AppLogger.log('[Meta] AdImpression value=$value');
    } catch (e) {
      AppLogger.error('[Meta] logAdImpression error', e);
    }
  }

  // ── Calls ─────────────────────────────────────────────────────────────────────

  static Future<void> logVoiceCallStarted() => _log('VoiceCallStarted');
  static Future<void> logVideoCallStarted() => _log('VideoCallStarted');
  static Future<void> logRandomChatStarted() => _log('RandomChatStarted');

  // ── Profile ───────────────────────────────────────────────────────────────────

  static Future<void> logProfileCompleted() => _log('ProfileCompleted');
  static Future<void> logPhotoUnlocked() => _log('PhotoUnlocked');
}
