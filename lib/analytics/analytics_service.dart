import 'meta_events.dart';
import 'firebase_events.dart';

// Unified analytics service — dual-fires Meta + Firebase for every event.
// Mirrors RN src/analytics/index.js.
// Use this class everywhere in the app; never call MetaEvents or FirebaseEvents directly.
class AnalyticsService {
  // ── Identity ─────────────────────────────────────────────────────────────────

  static Future<void> setUserId(String userId) async {
    await Future.wait([
      FirebaseEvents.setUserId(userId),
      MetaEvents.setUserId(userId),
    ]);
  }

  static Future<void> clearUserId() async {
    await MetaEvents.clearUserId();
  }

  static Future<void> setUserProperty(String name, String value) =>
      FirebaseEvents.setUserProperty(name, value);

  static Future<void> setUserProperties(Map<String, String> props) =>
      FirebaseEvents.setUserProperties(props);

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static Future<void> logSignupStart({String method = 'google'}) async {
    await Future.wait([
      MetaEvents.logSignupStart(method: method),
      FirebaseEvents.logSignupStart(method: method),
    ]);
  }

  static Future<void> logSignupComplete({String method = 'google'}) async {
    await Future.wait([
      MetaEvents.logCompleteRegistration(method: method),
      MetaEvents.logSignupComplete(method: method),
      FirebaseEvents.logSignupComplete(method: method),
      FirebaseEvents.logSignUp(method: method),
    ]);
  }

  static Future<void> logLogin({String method = 'google'}) async {
    await Future.wait([
      MetaEvents.logLogin(method: method),
      FirebaseEvents.logLogin(method: method),
    ]);
  }

  // ── Content & Feed ────────────────────────────────────────────────────────────

  static Future<void> logFeedMomentPosted({
    required String postType,
    required String mediaType,
  }) async {
    await Future.wait([
      MetaEvents.logPostCreated(postType: postType, mediaType: mediaType),
      FirebaseEvents.logFeedMomentPosted(postType: postType, mediaType: mediaType),
    ]);
  }

  static Future<void> logSearch({required String searchTerm}) async {
    await Future.wait([
      MetaEvents.logSearch(searchString: searchTerm),
      FirebaseEvents.logSearch(searchTerm: searchTerm),
    ]);
  }

  // ── Community / Messages ──────────────────────────────────────────────────────

  static Future<void> logCommunityMessageSent({
    required String communityId,
    required String messageType,
  }) async {
    await Future.wait([
      MetaEvents.logCommunityMessageSent(
          communityId: communityId, messageType: messageType),
      FirebaseEvents.logCommunityMessageSent(
          communityId: communityId, messageType: messageType),
    ]);
  }

  // ── Adda / Audio Rooms ────────────────────────────────────────────────────────

  static Future<void> logJoinAdda({
    required String addaId,
    required String addaTopic,
    required int numberOfUsers,
  }) async {
    await Future.wait([
      MetaEvents.logJoinAdda(
          addaId: addaId, addaTopic: addaTopic, numberOfUsers: numberOfUsers),
      FirebaseEvents.logJoinAdda(
          addaId: addaId, addaTopic: addaTopic, numberOfUsers: numberOfUsers),
    ]);
  }

  static Future<void> logCreateAdda({String addaTopic = ''}) async {
    await Future.wait([
      MetaEvents.logCreateAdda(addaTopic: addaTopic),
      FirebaseEvents.logCreateAdda(addaTopic: addaTopic),
    ]);
  }

  static Future<void> logAddaSeatTaken({
    required String addaId,
    required int seatIndex,
    required String addaTopic,
  }) async {
    await Future.wait([
      MetaEvents.logAddaSeatTaken(
          addaId: addaId, seatIndex: seatIndex, addaTopic: addaTopic),
      FirebaseEvents.logAddaSeatTaken(
          addaId: addaId, seatIndex: seatIndex, addaTopic: addaTopic),
    ]);
  }

  static Future<void> logAddaSpeakerUnmuted({
    required String addaId,
    int? seatIndex,
  }) async {
    await Future.wait([
      MetaEvents.logAddaSpeakerUnmuted(addaId: addaId, seatIndex: seatIndex),
      FirebaseEvents.logAddaSpeakerUnmuted(addaId: addaId, seatIndex: seatIndex),
    ]);
  }

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
  }) async {
    await Future.wait([
      MetaEvents.logAddaLeft(
        addaId: addaId, addaTopic: addaTopic, durationSec: durationSec,
        speakingSec: speakingSec, mutedSec: mutedSec, silentSec: silentSec,
        speakingPct: speakingPct, wasOnStage: wasOnStage, userRole: userRole,
        participantCount: participantCount, powerUserTier: powerUserTier,
      ),
      FirebaseEvents.logAddaLeft(
        addaId: addaId, addaTopic: addaTopic, durationSec: durationSec,
        speakingSec: speakingSec, mutedSec: mutedSec, silentSec: silentSec,
        speakingPct: speakingPct, wasOnStage: wasOnStage, userRole: userRole,
        participantCount: participantCount, powerUserTier: powerUserTier,
      ),
    ]);
  }

  // ── Engagement ────────────────────────────────────────────────────────────────

  static Future<void> logDailyActiveUser({
    required int consecutiveDays,
    required String engagementTier,
  }) async {
    await Future.wait([
      MetaEvents.logDailyActiveUser(
          consecutiveDays: consecutiveDays, engagementTier: engagementTier),
      FirebaseEvents.logDailyActiveUser(
          consecutiveDays: consecutiveDays, engagementTier: engagementTier),
    ]);
  }

  static Future<void> logConversation5Min({
    required String addaId,
    required String addaTopic,
    required int participantCount,
    required String userRole,
  }) async {
    await Future.wait([
      MetaEvents.logConversation5Min(
          addaId: addaId, addaTopic: addaTopic,
          participantCount: participantCount, userRole: userRole),
      FirebaseEvents.logConversation5Min(
          addaId: addaId, addaTopic: addaTopic,
          participantCount: participantCount, userRole: userRole),
    ]);
  }

  static Future<void> logConversation15Min({
    required String addaId,
    required String addaTopic,
    required int participantCount,
    required String userRole,
  }) async {
    await Future.wait([
      MetaEvents.logConversation15Min(
          addaId: addaId, addaTopic: addaTopic,
          participantCount: participantCount, userRole: userRole),
      FirebaseEvents.logConversation15Min(
          addaId: addaId, addaTopic: addaTopic,
          participantCount: participantCount, userRole: userRole),
    ]);
  }

  static Future<void> logConversation30Min({
    required String addaId,
    required String addaTopic,
    required int participantCount,
    required String userRole,
  }) async {
    await Future.wait([
      MetaEvents.logConversation30Min(
          addaId: addaId, addaTopic: addaTopic,
          participantCount: participantCount, userRole: userRole),
      FirebaseEvents.logConversation30Min(
          addaId: addaId, addaTopic: addaTopic,
          participantCount: participantCount, userRole: userRole),
    ]);
  }

  // ── Retention ─────────────────────────────────────────────────────────────────

  static Future<void> logRetentionD1() async {
    await Future.wait([MetaEvents.logRetentionD1(), FirebaseEvents.logRetentionD1()]);
  }

  static Future<void> logRetentionD3() async {
    await Future.wait([MetaEvents.logRetentionD3(), FirebaseEvents.logRetentionD3()]);
  }

  static Future<void> logRetentionD7() async {
    await Future.wait([MetaEvents.logRetentionD7(), FirebaseEvents.logRetentionD7()]);
  }

  static Future<void> logRetentionD14() async {
    await Future.wait([MetaEvents.logRetentionD14(), FirebaseEvents.logRetentionD14()]);
  }

  static Future<void> logRetentionD30() async {
    await Future.wait([MetaEvents.logRetentionD30(), FirebaseEvents.logRetentionD30()]);
  }

  static Future<void> logConsecutive3Days() async {
    await Future.wait([MetaEvents.logConsecutive3Days(), FirebaseEvents.logConsecutive3Days()]);
  }

  static Future<void> logConsecutive7Days() async {
    await Future.wait([MetaEvents.logConsecutive7Days(), FirebaseEvents.logConsecutive7Days()]);
  }

  static Future<void> logConsecutive14Days() async {
    await Future.wait([MetaEvents.logConsecutive14Days(), FirebaseEvents.logConsecutive14Days()]);
  }

  // ── Host Quality Events ───────────────────────────────────────────────────────

  static Future<void> logHosted30MinRoom({
    required String addaId,
    required int durationMin,
  }) async {
    await Future.wait([
      MetaEvents.logHosted30MinRoom(addaId: addaId, durationMin: durationMin),
      FirebaseEvents.logHosted30MinRoom(addaId: addaId, durationMin: durationMin),
    ]);
  }

  static Future<void> logRoomWith5Speakers({
    required String addaId,
    required int speakerCount,
  }) async {
    await Future.wait([
      MetaEvents.logRoomWith5Speakers(addaId: addaId, speakerCount: speakerCount),
      FirebaseEvents.logRoomWith5Speakers(addaId: addaId, speakerCount: speakerCount),
    ]);
  }

  static Future<void> logHostedActiveRoom({
    required String addaId,
    required int activeSpeakers,
    required int durationMin,
  }) async {
    await Future.wait([
      MetaEvents.logHostedActiveRoom(
          addaId: addaId, activeSpeakers: activeSpeakers, durationMin: durationMin),
      FirebaseEvents.logHostedActiveRoom(
          addaId: addaId, activeSpeakers: activeSpeakers, durationMin: durationMin),
    ]);
  }

  // ── User Quality Tier ─────────────────────────────────────────────────────────

  static Future<void> logUserQualityTier({
    required String tier,
    required int score,
  }) async {
    await Future.wait([
      MetaEvents.logUserQualityTier(tier: tier, score: score),
      FirebaseEvents.logUserQualityTier(tier: tier, score: score),
    ]);
  }

  // ── Account Lifecycle ─────────────────────────────────────────────────────────

  static Future<void> logAccountDeletionStarted(Map<String, dynamic> payload) async {
    final safePayload = payload.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await Future.wait([
      MetaEvents.logAccountDeletionStarted(payload),
      FirebaseEvents.logAccountDeletionStarted(
          safePayload.map((k, v) => MapEntry(k, v as Object))),
    ]);
  }

  static Future<void> logAccountDeletionCancelled(Map<String, dynamic> payload) async {
    final safePayload = payload.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await Future.wait([
      MetaEvents.logAccountDeletionCancelled(payload),
      FirebaseEvents.logAccountDeletionCancelled(
          safePayload.map((k, v) => MapEntry(k, v as Object))),
    ]);
  }

  static Future<void> logAccountDeleted(Map<String, dynamic> payload) async {
    final safePayload = payload.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await Future.wait([
      MetaEvents.logAccountDeleted(payload),
      FirebaseEvents.logAccountDeleted(
          safePayload.map((k, v) => MapEntry(k, v as Object))),
    ]);
  }

  // ── Churn Signals ─────────────────────────────────────────────────────────────

  static Future<void> logChurnRiskIncreased({
    required String fromTier,
    required String toTier,
    required int churnScore,
    required String trigger,
  }) async {
    await Future.wait([
      MetaEvents.logChurnRiskIncreased(
          fromTier: fromTier, toTier: toTier,
          churnScore: churnScore, trigger: trigger),
      FirebaseEvents.logChurnRiskIncreased(
          fromTier: fromTier, toTier: toTier,
          churnScore: churnScore, trigger: trigger),
    ]);
  }

  static Future<void> logUserEnteredHighRiskState({
    required int churnScore,
    required String trigger,
  }) async {
    await Future.wait([
      MetaEvents.logUserEnteredHighRiskState(
          churnScore: churnScore, trigger: trigger),
      FirebaseEvents.logUserEnteredHighRiskState(
          churnScore: churnScore, trigger: trigger),
    ]);
  }

  static Future<void> logUserRecoveredFromHighRisk({
    required int churnScore,
    required int daysAtRisk,
  }) async {
    await Future.wait([
      MetaEvents.logUserRecoveredFromHighRisk(
          churnScore: churnScore, daysAtRisk: daysAtRisk),
      FirebaseEvents.logUserRecoveredFromHighRisk(
          churnScore: churnScore, daysAtRisk: daysAtRisk),
    ]);
  }

  // ── Social ────────────────────────────────────────────────────────────────────

  static Future<void> logMutualFriendship() async {
    await Future.wait([
      MetaEvents.logMutualFriendship(),
      FirebaseEvents.logMutualFriendship(),
    ]);
  }

  static Future<void> logRepeatedUserInteraction() async {
    await Future.wait([
      MetaEvents.logRepeatedUserInteraction(),
      FirebaseEvents.logRepeatedUserInteraction(),
    ]);
  }

  static Future<void> logReturnedToSameAdda({required String addaId}) async {
    await Future.wait([
      MetaEvents.logReturnedToSameAdda(addaId: addaId),
      FirebaseEvents.logReturnedToSameAdda(addaId: addaId),
    ]);
  }

  // ── Ad Impression ─────────────────────────────────────────────────────────────

  static Future<void> logAdImpression({
    required double value,
    String currency = 'USD',
  }) =>
      MetaEvents.logAdImpression(value: value, currency: currency);
}
