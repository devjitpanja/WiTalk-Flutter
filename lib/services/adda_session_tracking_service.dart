import 'dart:async';
import '../analytics/analytics_service.dart';
import '../analytics/firebase_events.dart';
import '../utils/logger.dart';
import 'churn_tracking_service.dart';

// Mirrors RN useAddaSessionTracking.js
// Tracks per-room session analytics: duration milestones, speaking time breakdown,
// host quality events, and the full leave event with stage stats.
//
// Usage in LiveAudioRoomScreen:
//   final _sessionTracking = AddaSessionTrackingService();
//   _sessionTracking.startSession(...)  // on room join
//   _sessionTracking.onSeatTaken(...)   // when user takes a seat
//   _sessionTracking.onUnmuted()        // when user unmutes
//   _sessionTracking.onMuted()          // when user mutes
//   _sessionTracking.onSpeakerCountChanged(n) // when speaker count changes
//   _sessionTracking.onParticipantCountChanged(n)
//   await _sessionTracking.onLeave()    // on leave/end
class AddaSessionTrackingService {
  String? _roomId;
  String? _roomName;
  String? _userRole; // 'host' | 'audience' | 'speaker'
  bool _isHost = false;

  // Timestamps
  DateTime? _joinTime;
  DateTime? _stageEntryTime;

  // Second-level counters (incremented every second by _ticker)
  int _speakingSec = 0;
  int _mutedSec = 0;
  int _silentSec = 0; // time in audience (not on stage)

  // State flags
  bool _isOnStage = false;
  bool _isMuted = true;
  int _participantCount = 0;
  int _speakerCount = 0;

  // Milestone timers
  Timer? _ticker;
  Timer? _timer5;
  Timer? _timer15;
  Timer? _timer30;
  Timer? _timerHost30;

  // Host quality: room_with_5_speakers
  DateTime? _fiveSpeakersStartTime;
  bool _firedRoomWith5Speakers = false;

  // Host quality: hosted_active_room (3+ speakers for 10+ min)
  DateTime? _activeRoomStartTime;
  bool _firedHostedActiveRoom = false;

  bool _started = false;
  bool _left = false;

  void startSession({
    required String roomId,
    required String roomName,
    required String userRole,
    required bool isHost,
    required int participantCount,
    bool isMuted = true,
  }) {
    if (_started) return;
    _started = true;
    _left = false;
    _roomId = roomId;
    _roomName = roomName;
    _userRole = userRole;
    _isHost = isHost;
    _participantCount = participantCount;
    _isMuted = isMuted;
    _joinTime = DateTime.now();

    // Second-level ticker for speaking/muted/silent tracking
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Conversation milestones
    _timer5 = Timer(const Duration(minutes: 5), _onFiveMin);
    _timer15 = Timer(const Duration(minutes: 15), _onFifteenMin);
    _timer30 = Timer(const Duration(minutes: 30), _onThirtyMin);

    // Host-only: hosted_30min_room
    if (_isHost) {
      _timerHost30 = Timer(const Duration(minutes: 30), _onHostThirtyMin);
    }

    AppLogger.log('[Session] started roomId=$roomId role=$userRole');
  }

  void _tick() {
    if (_left) return;
    if (_isOnStage) {
      if (_isMuted) {
        _mutedSec++;
      } else {
        _speakingSec++;
      }
    } else {
      _silentSec++;
    }
  }

  void onSeatTaken(int seatIndex) {
    if (_left) return;
    _isOnStage = true;
    _stageEntryTime = DateTime.now();
    _userRole = _isHost ? 'host' : 'speaker';
    AppLogger.log('[Session] seat taken index=$seatIndex');
  }

  void onLeftSeat() {
    if (_left) return;
    _isOnStage = false;
    _userRole = _isHost ? 'host' : 'audience';
  }

  void onUnmuted() {
    if (_left) return;
    _isMuted = false;
  }

  void onMuted() {
    if (_left) return;
    _isMuted = true;
  }

  void onParticipantCountChanged(int count) {
    _participantCount = count;
  }

  void onSpeakerCountChanged(int count) {
    if (_left) return;
    _speakerCount = count;

    if (_isHost) {
      _checkRoomWith5Speakers();
      _checkHostedActiveRoom();
    }
  }

  void _checkRoomWith5Speakers() {
    final id = _roomId;
    if (id == null || _firedRoomWith5Speakers) return;

    if (_speakerCount >= 5) {
      if (_fiveSpeakersStartTime == null) {
        _fiveSpeakersStartTime = DateTime.now();
      }
    } else {
      _fiveSpeakersStartTime = null;
    }

    if (_fiveSpeakersStartTime != null &&
        DateTime.now().difference(_fiveSpeakersStartTime!).inMinutes >= 1) {
      _firedRoomWith5Speakers = true;
      AnalyticsService.logRoomWith5Speakers(
        addaId: id,
        speakerCount: _speakerCount,
      );
    }
  }

  void _checkHostedActiveRoom() {
    final id = _roomId;
    if (id == null || _firedHostedActiveRoom) return;

    if (_speakerCount >= 3) {
      _activeRoomStartTime ??= DateTime.now();
    } else {
      _activeRoomStartTime = null;
    }

    if (_activeRoomStartTime != null) {
      final durationMin =
          DateTime.now().difference(_activeRoomStartTime!).inMinutes;
      if (durationMin >= 10) {
        _firedHostedActiveRoom = true;
        AnalyticsService.logHostedActiveRoom(
          addaId: id,
          activeSpeakers: _speakerCount,
          durationMin: durationMin,
        );
      }
    }
  }

  void _onFiveMin() {
    final id = _roomId;
    if (id == null || _left) return;
    AnalyticsService.logConversation5Min(
      addaId: id,
      addaTopic: _roomName ?? '',
      participantCount: _participantCount,
      userRole: _userRole ?? 'audience',
    );
  }

  void _onFifteenMin() {
    final id = _roomId;
    if (id == null || _left) return;
    AnalyticsService.logConversation15Min(
      addaId: id,
      addaTopic: _roomName ?? '',
      participantCount: _participantCount,
      userRole: _userRole ?? 'audience',
    );
  }

  void _onThirtyMin() {
    final id = _roomId;
    if (id == null || _left) return;
    AnalyticsService.logConversation30Min(
      addaId: id,
      addaTopic: _roomName ?? '',
      participantCount: _participantCount,
      userRole: _userRole ?? 'audience',
    );
  }

  void _onHostThirtyMin() {
    final id = _roomId;
    if (id == null || _left) return;
    AnalyticsService.logHosted30MinRoom(addaId: id, durationMin: 30);
  }

  /// Call when user leaves or room ends. Fires the full leave event, stage session
  /// event (if was on stage), updates power_user_tier, and recomputes churn.
  Future<void> onLeave() async {
    if (_left || _roomId == null) return;
    _left = true;
    _started = false;
    _cancelTimers();

    final id = _roomId!;
    final name = _roomName ?? '';
    final durationSec =
        _joinTime != null ? DateTime.now().difference(_joinTime!).inSeconds : 0;
    final totalSec = (_speakingSec + _mutedSec + _silentSec).clamp(1, durationSec + 1);
    final speakingPct = (((_speakingSec / totalSec) * 100).roundToDouble());
    final wasOnStage = _isOnStage || _stageEntryTime != null ? 1 : 0;
    final stageSec = (_speakingSec + _mutedSec).clamp(0, durationSec);
    final stagePct = ((stageSec / totalSec) * 100).roundToDouble();

    // Determine power_user_tier (mirrors RN logic)
    final String powerUserTier;
    if (_speakingSec > 300) {
      powerUserTier = 'power_speaker';
    } else if (_speakingSec > 60) {
      powerUserTier = 'active_speaker';
    } else if (wasOnStage == 1) {
      powerUserTier = 'stage_lurker';
    } else {
      powerUserTier = 'silent_listener';
    }

    final userRole = _userRole ?? 'audience';

    // Fire adda_left (Meta + Firebase)
    await AnalyticsService.logAddaLeft(
      addaId: id,
      addaTopic: name,
      durationSec: durationSec,
      speakingSec: _speakingSec,
      mutedSec: _mutedSec,
      silentSec: _silentSec,
      speakingPct: speakingPct,
      wasOnStage: wasOnStage,
      userRole: userRole,
      participantCount: _participantCount,
      powerUserTier: powerUserTier,
    );

    // adda_stage_session — Firebase only, if was ever on stage
    if (wasOnStage == 1) {
      await FirebaseEvents.logAddaStageSession(
        addaId: id,
        speakingSec: _speakingSec,
        mutedSec: _mutedSec,
        stagePct: stagePct,
        speakingPct: speakingPct,
      );
    }

    // Update power_user_tier Firebase user property
    await FirebaseEvents.setUserProperty('power_user_tier', powerUserTier);

    // Compute quality tier score (simplified mirrors RN)
    final qualityScore = _computeQualityScore(
      durationSec: durationSec,
      speakingSec: _speakingSec,
      wasOnStage: wasOnStage,
    );
    final qualityTier = _qualityTierFromScore(qualityScore);
    await AnalyticsService.logUserQualityTier(tier: qualityTier, score: qualityScore);
    await FirebaseEvents.setUserProperty('user_quality_tier', qualityTier);

    // Write churn signals
    final fastExit = durationSec < 60;
    final silentExit = _speakingSec == 0 && wasOnStage == 0;
    await ChurnTrackingService.writeSessionSignals(
      wasOnStage: wasOnStage == 1,
      fastExit: fastExit,
      silentExit: silentExit,
      hasFriends: true, // unknown from this context; default optimistic
      didSpeak: _speakingSec > 0,
    );

    // Recompute churn risk
    await ChurnTrackingService.recomputeChurnRisk('session_end');

    AppLogger.log('[Session] leave durationSec=$durationSec speaking=$_speakingSec '
        'muted=$_mutedSec silent=$_silentSec tier=$powerUserTier');
  }

  int _computeQualityScore({
    required int durationSec,
    required int speakingSec,
    required int wasOnStage,
  }) {
    int score = 0;
    if (durationSec >= 300) score += 20;
    if (durationSec >= 900) score += 20;
    if (durationSec >= 1800) score += 20;
    if (wasOnStage == 1) score += 20;
    if (speakingSec >= 60) score += 20;
    return score.clamp(0, 100);
  }

  String _qualityTierFromScore(int score) {
    if (score >= 80) return 'core_community_user';
    if (score >= 60) return 'high_intent_user';
    if (score >= 40) return 'medium_intent_user';
    return 'low_intent_user';
  }

  void _cancelTimers() {
    _ticker?.cancel();
    _timer5?.cancel();
    _timer15?.cancel();
    _timer30?.cancel();
    _timerHost30?.cancel();
  }

  void dispose() {
    _cancelTimers();
  }
}
