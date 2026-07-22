import 'dart:async';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/livekit_audio_manager.dart';
import '../services/socket_service.dart';
import '../services/audio_room_service.dart';
import '../services/seat_manager.dart';
import '../services/participant_manager.dart';
import 'auth_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AudioRoomState {
  // ── Identity ───────────────────────────────────────────────────────────────
  final String? roomId;
  final String roomName;
  final String? topic;
  final String? hostUid;
  final String? hostName;
  final String? hostProfilePic;
  final String? language;
  final int maxSeats;
  final bool isPublic;

  // ── My role ────────────────────────────────────────────────────────────────
  final bool isHost;
  final bool isCoHost;
  final bool isAdmin;
  final bool isSpeaker;
  final bool isMuted;
  final bool mutedByHost;
  final bool isMicLoading;
  final bool isHandRaised;
  final int currentSeatIndex;
  final bool isInSeat;

  // ── Connection ─────────────────────────────────────────────────────────────
  final bool isMinimised;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  // ── Seat layout ────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> speakers; // Seat grid (seats 0..maxSeats-1)
  final List<Map<String, dynamic>> audience; // Audience list
  final bool seatsInitialized;
  final Set<int> lockedSeats;

  // ── Hand raise / seat requests ─────────────────────────────────────────────
  final List<Map<String, dynamic>> handRaiseQueue;
  final Map<String, dynamic>? incomingSeatInvite; // { uid, seatIndex }

  // ── Participants ───────────────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> participantProfiles;

  // ── Audio / output ─────────────────────────────────────────────────────────
  final String? activeSpeakerUid;
  final Map<String, double> soundLevels; // uid → 0.0-1.0
  final String audioOutputMode; // 'speaker' | 'earpiece' | 'bluetooth'

  // ── Chat ───────────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> chatMessages;
  final Map<String, dynamic>? pinnedMessage;
  final bool pinnedLocallyDismissed;
  final Map<String, dynamic>? replyingTo; // { id, senderName, text }

  // ── Room config / admin ────────────────────────────────────────────────────
  final List<String> admins;
  final List<Map<String, dynamic>> bannedUsers;
  final Map<String, dynamic> communityRolesMap;
  final bool coolDownMode;
  final String? roomInviteToken;
  final bool isRoomPublic;
  final bool stageRequestEnabled;
  final String? roomRules;
  final bool rulesDismissed;
  final String? groupId;

  // ── Recording / rating ─────────────────────────────────────────────────────
  final bool cloudRecordingActive;
  final double? averageRating;
  final bool hasRated;

  // ── Room lifecycle ─────────────────────────────────────────────────────────
  final bool showRoomEndedScreen;
  final Map<String, dynamic>? hostProfileForEndedScreen;
  final bool closeFrozen;
  final bool actionsFrozen;

  // ── Daily limit ────────────────────────────────────────────────────────────
  final int dailyLimitMinutes;
  final int dailySpentSeconds;

  // ── YouTube watch-together ─────────────────────────────────────────────────
  final String? youtubeVideoId;
  final bool youtubeIsPlaying;
  final double youtubeCurrentTime;
  final double youtubeDuration;
  final bool youtubeIsBuffering;
  final bool showYoutubeSection;

  // ── Screen / camera share ──────────────────────────────────────────────────
  final Map<String, dynamic>? screenShareInfo;
  final bool isScreenSharing;
  final List<Map<String, dynamic>> cameraShareInfos;

  // ── UI helpers ─────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> activeReactions;
  final Map<String, dynamic>? alertDialogConfig;
  final bool showAlertDialog;

  // ── Leave dialog ───────────────────────────────────────────────────────────
  final Map<String, dynamic>? leaveDialogConfig;
  final bool showLeaveDialog;

  // ── Access / community ────────────────────────────────────────────────────
  final bool canTakeAddaSeat;
  final String? myCommunityRole;
  final String? channelName;

  // ── Navigation signals ────────────────────────────────────────────────────
  final bool shouldNavigateBack; // host ends own room → just pop, no ended screen
  final bool kickedFromRoom;     // kicked → toast + navigate back
  final bool bannedFromRoom;     // banned → toast + navigate back

  const AudioRoomState({
    this.roomId,
    this.roomName = 'WiTalk Adda',
    this.topic,
    this.hostUid,
    this.hostName,
    this.hostProfilePic,
    this.language,
    this.maxSeats = 8,
    this.isPublic = true,
    this.isHost = false,
    this.isCoHost = false,
    this.isAdmin = false,
    this.isSpeaker = false,
    this.isMuted = true,
    this.mutedByHost = false,
    this.isMicLoading = false,
    this.isHandRaised = false,
    this.currentSeatIndex = -1,
    this.isInSeat = false,
    this.isMinimised = false,
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.speakers = const [],
    this.audience = const [],
    this.seatsInitialized = false,
    this.lockedSeats = const {},
    this.handRaiseQueue = const [],
    this.incomingSeatInvite,
    this.participantProfiles = const {},
    this.activeSpeakerUid,
    this.soundLevels = const {},
    this.audioOutputMode = 'speaker',
    this.chatMessages = const [],
    this.pinnedMessage,
    this.pinnedLocallyDismissed = false,
    this.replyingTo,
    this.admins = const [],
    this.bannedUsers = const [],
    this.communityRolesMap = const {},
    this.coolDownMode = false,
    this.roomInviteToken,
    this.isRoomPublic = true,
    this.stageRequestEnabled = true,
    this.roomRules,
    this.rulesDismissed = false,
    this.groupId,
    this.cloudRecordingActive = false,
    this.averageRating,
    this.hasRated = false,
    this.showRoomEndedScreen = false,
    this.hostProfileForEndedScreen,
    this.closeFrozen = false,
    this.actionsFrozen = false,
    this.dailyLimitMinutes = 0,
    this.dailySpentSeconds = 0,
    this.youtubeVideoId,
    this.youtubeIsPlaying = false,
    this.youtubeCurrentTime = 0.0,
    this.youtubeDuration = 0.0,
    this.youtubeIsBuffering = false,
    this.showYoutubeSection = false,
    this.screenShareInfo,
    this.isScreenSharing = false,
    this.cameraShareInfos = const [],
    this.activeReactions = const [],
    this.alertDialogConfig,
    this.showAlertDialog = false,
    this.leaveDialogConfig,
    this.showLeaveDialog = false,
    this.canTakeAddaSeat = true,
    this.myCommunityRole,
    this.channelName,
    this.shouldNavigateBack = false,
    this.kickedFromRoom = false,
    this.bannedFromRoom = false,
  });

  AudioRoomState copyWith({
    String? roomId,
    String? roomName,
    String? topic,
    Object? hostUid = _sentinel,
    String? hostName,
    String? hostProfilePic,
    String? language,
    int? maxSeats,
    bool? isPublic,
    bool? isHost,
    bool? isCoHost,
    bool? isAdmin,
    bool? isSpeaker,
    bool? isMuted,
    bool? mutedByHost,
    bool? isMicLoading,
    bool? isHandRaised,
    int? currentSeatIndex,
    bool? isInSeat,
    bool? isMinimised,
    bool? isConnected,
    bool? isLoading,
    Object? error = _sentinel,
    List<Map<String, dynamic>>? speakers,
    List<Map<String, dynamic>>? audience,
    bool? seatsInitialized,
    Set<int>? lockedSeats,
    List<Map<String, dynamic>>? handRaiseQueue,
    Object? incomingSeatInvite = _sentinel,
    Map<String, Map<String, dynamic>>? participantProfiles,
    Object? activeSpeakerUid = _sentinel,
    Map<String, double>? soundLevels,
    String? audioOutputMode,
    List<Map<String, dynamic>>? chatMessages,
    Object? pinnedMessage = _sentinel,
    bool? pinnedLocallyDismissed,
    Object? replyingTo = _sentinel,
    List<String>? admins,
    List<Map<String, dynamic>>? bannedUsers,
    Map<String, dynamic>? communityRolesMap,
    bool? coolDownMode,
    String? roomInviteToken,
    bool? isRoomPublic,
    bool? stageRequestEnabled,
    Object? roomRules = _sentinel,
    bool? rulesDismissed,
    String? groupId,
    bool? cloudRecordingActive,
    double? averageRating,
    bool? hasRated,
    bool? showRoomEndedScreen,
    Object? hostProfileForEndedScreen = _sentinel,
    bool? closeFrozen,
    bool? actionsFrozen,
    int? dailyLimitMinutes,
    int? dailySpentSeconds,
    Object? youtubeVideoId = _sentinel,
    bool? youtubeIsPlaying,
    double? youtubeCurrentTime,
    double? youtubeDuration,
    bool? youtubeIsBuffering,
    bool? showYoutubeSection,
    Object? screenShareInfo = _sentinel,
    bool? isScreenSharing,
    List<Map<String, dynamic>>? cameraShareInfos,
    List<Map<String, dynamic>>? activeReactions,
    Object? alertDialogConfig = _sentinel,
    bool? showAlertDialog,
    Object? leaveDialogConfig = _sentinel,
    bool? showLeaveDialog,
    bool? canTakeAddaSeat,
    Object? myCommunityRole = _sentinel,
    Object? channelName = _sentinel,
    bool? shouldNavigateBack,
    bool? kickedFromRoom,
    bool? bannedFromRoom,
  }) {
    return AudioRoomState(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      topic: topic ?? this.topic,
      hostUid: hostUid == _sentinel ? this.hostUid : hostUid as String?,
      hostName: hostName ?? this.hostName,
      hostProfilePic: hostProfilePic ?? this.hostProfilePic,
      language: language ?? this.language,
      maxSeats: maxSeats ?? this.maxSeats,
      isPublic: isPublic ?? this.isPublic,
      isHost: isHost ?? this.isHost,
      isCoHost: isCoHost ?? this.isCoHost,
      isAdmin: isAdmin ?? this.isAdmin,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isMuted: isMuted ?? this.isMuted,
      mutedByHost: mutedByHost ?? this.mutedByHost,
      isMicLoading: isMicLoading ?? this.isMicLoading,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      currentSeatIndex: currentSeatIndex ?? this.currentSeatIndex,
      isInSeat: isInSeat ?? this.isInSeat,
      isMinimised: isMinimised ?? this.isMinimised,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      speakers: speakers ?? this.speakers,
      audience: audience ?? this.audience,
      seatsInitialized: seatsInitialized ?? this.seatsInitialized,
      lockedSeats: lockedSeats ?? this.lockedSeats,
      handRaiseQueue: handRaiseQueue ?? this.handRaiseQueue,
      incomingSeatInvite: incomingSeatInvite == _sentinel
          ? this.incomingSeatInvite
          : incomingSeatInvite as Map<String, dynamic>?,
      participantProfiles: participantProfiles ?? this.participantProfiles,
      activeSpeakerUid: activeSpeakerUid == _sentinel
          ? this.activeSpeakerUid
          : activeSpeakerUid as String?,
      soundLevels: soundLevels ?? this.soundLevels,
      audioOutputMode: audioOutputMode ?? this.audioOutputMode,
      chatMessages: chatMessages ?? this.chatMessages,
      pinnedMessage: pinnedMessage == _sentinel
          ? this.pinnedMessage
          : pinnedMessage as Map<String, dynamic>?,
      pinnedLocallyDismissed:
          pinnedLocallyDismissed ?? this.pinnedLocallyDismissed,
      replyingTo: replyingTo == _sentinel
          ? this.replyingTo
          : replyingTo as Map<String, dynamic>?,
      admins: admins ?? this.admins,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      communityRolesMap: communityRolesMap ?? this.communityRolesMap,
      coolDownMode: coolDownMode ?? this.coolDownMode,
      roomInviteToken: roomInviteToken ?? this.roomInviteToken,
      isRoomPublic: isRoomPublic ?? this.isRoomPublic,
      stageRequestEnabled: stageRequestEnabled ?? this.stageRequestEnabled,
      roomRules:
          roomRules == _sentinel ? this.roomRules : roomRules as String?,
      rulesDismissed: rulesDismissed ?? this.rulesDismissed,
      groupId: groupId ?? this.groupId,
      cloudRecordingActive: cloudRecordingActive ?? this.cloudRecordingActive,
      averageRating: averageRating ?? this.averageRating,
      hasRated: hasRated ?? this.hasRated,
      showRoomEndedScreen: showRoomEndedScreen ?? this.showRoomEndedScreen,
      hostProfileForEndedScreen: hostProfileForEndedScreen == _sentinel
          ? this.hostProfileForEndedScreen
          : hostProfileForEndedScreen as Map<String, dynamic>?,
      closeFrozen: closeFrozen ?? this.closeFrozen,
      actionsFrozen: actionsFrozen ?? this.actionsFrozen,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      dailySpentSeconds: dailySpentSeconds ?? this.dailySpentSeconds,
      youtubeVideoId: youtubeVideoId == _sentinel
          ? this.youtubeVideoId
          : youtubeVideoId as String?,
      youtubeIsPlaying: youtubeIsPlaying ?? this.youtubeIsPlaying,
      youtubeCurrentTime: youtubeCurrentTime ?? this.youtubeCurrentTime,
      youtubeDuration: youtubeDuration ?? this.youtubeDuration,
      youtubeIsBuffering: youtubeIsBuffering ?? this.youtubeIsBuffering,
      showYoutubeSection: showYoutubeSection ?? this.showYoutubeSection,
      screenShareInfo: screenShareInfo == _sentinel
          ? this.screenShareInfo
          : screenShareInfo as Map<String, dynamic>?,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      cameraShareInfos: cameraShareInfos ?? this.cameraShareInfos,
      activeReactions: activeReactions ?? this.activeReactions,
      alertDialogConfig: alertDialogConfig == _sentinel
          ? this.alertDialogConfig
          : alertDialogConfig as Map<String, dynamic>?,
      showAlertDialog: showAlertDialog ?? this.showAlertDialog,
      leaveDialogConfig: leaveDialogConfig == _sentinel
          ? this.leaveDialogConfig
          : leaveDialogConfig as Map<String, dynamic>?,
      showLeaveDialog: showLeaveDialog ?? this.showLeaveDialog,
      canTakeAddaSeat: canTakeAddaSeat ?? this.canTakeAddaSeat,
      myCommunityRole: myCommunityRole == _sentinel
          ? this.myCommunityRole
          : myCommunityRole as String?,
      channelName: channelName == _sentinel
          ? this.channelName
          : channelName as String?,
      shouldNavigateBack: shouldNavigateBack ?? this.shouldNavigateBack,
      kickedFromRoom: kickedFromRoom ?? this.kickedFromRoom,
      bannedFromRoom: bannedFromRoom ?? this.bannedFromRoom,
    );
  }
}

// Sentinel used in copyWith to distinguish "not passed" from null.
const _sentinel = Object();

// ── Notifier ──────────────────────────────────────────────────────────────────

class AudioRoomNotifier extends StateNotifier<AudioRoomState> {
  final Ref ref;

  // ── Internal services ──────────────────────────────────────────────────────
  final _seatManager = SeatManager();
  final _participantManager = ParticipantManager();

  // ── Subscriptions / timers ─────────────────────────────────────────────────
  final List<StreamSubscription> _liveKitSubs = [];
  final List<StreamSubscription> _managerSubs = [];
  Timer? _heartbeatTimer;
  Timer? _healthCheckTimer;
  Timer? _hostDepartureTimer;
  Timer? _dailyLimitTimer;
  Timer? _reactionCleanupTimer;
  Timer? _reactionCooldownTimer;

  // ── Mutable session state (mirrors RN refs) ────────────────────────────────
  String? _myUid;
  bool _roomClosedShown = false;
  int _dailySpentSecondsLocal = 0;
  bool _timeLimitFired = false;
  bool _reactionOnCooldown = false;
  // Reconnect tracking — mirrors lastReconnectedAtRef in RN
  int _lastReconnectedAt = 0;
  // Last join params for retry after connection error
  Map<String, dynamic>? _joinParams;
  // Seat change cooldown
  int _lastSeatChangeTime = 0;

  AudioRoomNotifier(this.ref) : super(const AudioRoomState());

  // ── Getters ────────────────────────────────────────────────────────────────
  SeatManager get seatManager => _seatManager;

  // ── joinRoom (the main entry point) ────────────────────────────────────────
  /// Joins a room:
  ///  1. Calls POST /v1/audio-rooms/{roomId}/join → gets livekit_token, stage_layout, user_data
  ///  2. Connects to the LiveKit server
  ///  3. Connects to Socket.IO and sets up all event listeners
  ///  4. Starts heartbeat, health check, and daily limit timers
  Future<bool> joinRoom(
    String roomId, {
    bool isHost = false,
    String role = 'audience',
  }) async {
    state = state.copyWith(isLoading: true, roomId: roomId, isHost: isHost);

    try {
      final authState = ref.read(authProvider);
      _myUid = authState.uid ?? '';
      final currentUid = _myUid!;

      // Read display name and photo URL from SharedPreferences (set on login)
      String myDisplayName = currentUid;
      String? myPhotoUrl;
      try {
        final prefs = await SharedPreferences.getInstance();
        myDisplayName = prefs.getString('display_name') ??
            prefs.getString('name') ??
            currentUid;
        myPhotoUrl = prefs.getString('profile_pic') ??
            prefs.getString('photo_url');
      } catch (_) {}

      // ── Step 1: Call backend join API ──────────────────────────────────────
      final effectiveRole = isHost ? 'host' : role;

      final joinResult = await audioRoomService.joinRoom(roomId, effectiveRole);

      if (joinResult['success'] != true) {
        final msg = joinResult['message'] ?? 'Failed to join room';
        state = state.copyWith(isLoading: false, error: msg.toString());
        return false;
      }

      // ── Step 2: Extract room metadata ──────────────────────────────────────
      final data =
          (joinResult['data'] ?? {}) as Map<String, dynamic>;

      // ── user_data access checks (mirrors RN initialize()) ──────────────────
      final userData = (data['user_data'] ?? joinResult['user_data'])
          as Map<String, dynamic>?;
      bool canTakeAddaSeat = true;
      if (userData != null) {
        // Access check — bail before doing anything else
        final access = userData['access'] as Map?;
        if (access != null && access['can_join_adda'] == false) {
          state = state.copyWith(
            isLoading: false,
            error: "You don't have permission to join Adda rooms.",
          );
          return false;
        }
        canTakeAddaSeat = access?['can_take_adda_seat'] != false;

        final fetchedName =
            userData['name']?.toString() ?? userData['username']?.toString();
        final fetchedPic = userData['profile_pic_medium']?.toString() ??
            userData['profile_pic']?.toString() ??
            userData['avatar']?.toString();
        if (fetchedName != null && fetchedName.isNotEmpty) {
          myDisplayName = fetchedName;
        }
        if (fetchedPic != null && fetchedPic.isNotEmpty) {
          myPhotoUrl = fetchedPic;
        }
      }

      // ── already_in_room: stale session from app force-kill ─────────────────
      // (mirrors RN check: re-leave then re-join once; if still flagged → multi-device)
      if (joinResult['already_in_room'] == true && !isHost) {
        try {
          await audioRoomService.leaveRoom(roomId);
        } catch (_) {}
        try {
          final retryResult = await audioRoomService.joinRoom(roomId, effectiveRole);
          if (retryResult['already_in_room'] == true) {
            state = state.copyWith(
              isLoading: false,
              error: 'You are already in this adda from another device. Please leave on the other device first.',
            );
            return false;
          }
          // Use the fresh result going forward — merged below
          joinResult.addAll(retryResult);
        } catch (_) {
          state = state.copyWith(
            isLoading: false,
            error: 'You are already in this adda from another device. Please leave on the other device first.',
          );
          return false;
        }
      }

      final livekitToken = joinResult['livekit_token']?.toString() ?? '';
      final livekitUrl = joinResult['livekit_url']?.toString() ?? '';
      final iceServers = joinResult['ice_servers'] as List<dynamic>?;

      final hostUid = data['host_uid']?.toString();
      final actualIsHost =
          isHost || (hostUid != null && hostUid == currentUid);
      final myRole = joinResult['my_role']?.toString() ?? effectiveRole;
      final actualIsAdmin =
          myRole == 'admin' || myRole == 'host' || actualIsHost;
      final myCommunityRole = joinResult['my_community_role']?.toString();

      final adminsList = data['admins'] as List?;
      final admins = adminsList?.map((e) {
        if (e is Map) return e['uid']?.toString() ?? e.toString();
        return e.toString();
      }).toList() ?? <String>[];
      final maxSeats = (data['max_seats'] as int?) ?? 8;
      final stageRequestEnabled = data['stage_request_enabled'] != null
          ? data['stage_request_enabled'] == 1 ||
              data['stage_request_enabled'] == true
          : true;

      // Detect cloud recording from join response (egress_id present)
      final cloudRecordingActive =
          data['cloud_recording_active'] == true ||
              data['cloud_recording_active'] == 1 ||
              (data['egress_id'] != null &&
                  data['egress_id'].toString().isNotEmpty);

      // Daily limit — hosts are exempt
      final dailyLimitMinutes = isHost
          ? 0
          : (joinResult['daily_limit_minutes'] as int?) ??
              (data['daily_limit_minutes'] as int?) ??
              0;
      // Seed daily spent seconds from join response
      final dailySpentSeconds = isHost
          ? 0
          : (joinResult['daily_spent_seconds'] as int?) ?? 0;
      _dailySpentSecondsLocal = dailySpentSeconds;

      // Seed seat manager
      _seatManager.isHost = actualIsHost;
      _seatManager.stageRequestEnabled = stageRequestEnabled;
      _seatManager.maxSeats = maxSeats;

      // Seed initial speakers list from stage_layout in join response
      final stageLayout =
          (joinResult['stage_layout'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
      final initialSeats = List<String?>.filled(maxSeats, null);
      for (final entry in stageLayout) {
        final uid = entry['uid']?.toString();
        final seatIndex = entry['seat_index'];
        final si = seatIndex is int
            ? seatIndex
            : int.tryParse(seatIndex?.toString() ?? '') ?? -1;
        if (uid != null && si >= 0 && si < maxSeats) {
          initialSeats[si] = uid;
        }
      }
      _seatManager.seats = initialSeats;

      // Seed participant manager from stage_layout
      _participantManager.initialize(roomId);
      _participantManager.seedFromStageLayout(stageLayout, hostUid: hostUid);
      _participantManager.seedParticipantRoles(data['admins'] as List? ?? []);

      // Seed self profile
      _participantManager.onParticipantJoined({
        'uid': currentUid,
        'name': myDisplayName,
        'profile_pic': myPhotoUrl,
        'avatar': myPhotoUrl,
        'isHost': actualIsHost,
        'isAdmin': actualIsAdmin,
        'role': myRole,
      });

      final initialSpeakers = _buildSpeakersFromSeatManager(hostUid, currentUid);

      state = state.copyWith(
        roomId: roomId,
        roomName: data['room_name']?.toString() ?? 'WiTalk Adda',
        topic: data['topic']?.toString(),
        hostUid: hostUid,
        hostName: data['host_name']?.toString() ??
            data['host_username']?.toString(),
        hostProfilePic: data['host_profile_pic']?.toString(),
        language: data['language']?.toString(),
        maxSeats: maxSeats,
        isPublic: data['is_public'] == true || data['is_public'] == 1,
        isHost: actualIsHost,
        isAdmin: actualIsAdmin,
        isSpeaker: actualIsHost,
        isMuted: !actualIsHost,
        currentSeatIndex: actualIsHost ? 0 : -1,
        isInSeat: actualIsHost,
        isConnected: true,
        isLoading: false,
        isMinimised: false,
        admins: admins,
        stageRequestEnabled: stageRequestEnabled,
        coolDownMode: data['cool_down_mode'] == true ||
            data['cool_down_mode'] == 1,
        isRoomPublic: data['is_public'] != 0 && data['is_public'] != false,
        roomInviteToken: data['invite_token']?.toString(),
        roomRules:
            data['room_rules']?.toString() ?? data['rules']?.toString(),
        groupId:
            data['group_id']?.toString() ?? data['groupId']?.toString(),
        cloudRecordingActive: cloudRecordingActive,
        averageRating: data['average_rating'] != null
            ? double.tryParse(data['average_rating'].toString())
            : null,
        speakers: initialSpeakers,
        audience: _buildAudienceFromProfiles(hostUid),
        seatsInitialized: false,
        participantProfiles:
            Map<String, Map<String, dynamic>>.from(
                _participantManager.profiles),
        dailyLimitMinutes: dailyLimitMinutes,
        dailySpentSeconds: dailySpentSeconds,
        canTakeAddaSeat: canTakeAddaSeat,
        myCommunityRole: myCommunityRole,
        channelName: data['channel_name']?.toString(),
      );

      // ── Step 3: Connect LiveKit ────────────────────────────────────────────
      if (livekitToken.isNotEmpty && livekitUrl.isNotEmpty) {
        liveKitAudioManager.prepareConnection(livekitUrl);

        await liveKitAudioManager.joinRoom(
          roomId: roomId,
          userId: currentUid,
          userName: myDisplayName,
          token: livekitToken,
          livekitUrl: livekitUrl,
          iceServers: iceServers
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );

        _listenToLiveKitEvents(currentUid, roomId);

        // Host starts publishing immediately
        if (actualIsHost) {
          try {
            await liveKitAudioManager.startPublishing();
            // NOTE: startPublishing() enables mic internally — do NOT call
            // setMicrophoneEnabled(true) again (causes double-enable on Android)
            final micStarted = liveKitAudioManager.isPublishing;
            state = state.copyWith(isMuted: !micStarted);
            if (micStarted && _myUid != null) {
              _participantManager.updateParticipantMic(_myUid!, true);
              liveKitAudioManager.sendRoomCommand(
                'MIC_STATE_CHANGED',
                data: {'userID': _myUid, 'isMicOn': true},
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print('[AudioRoomProvider] Host mic start failed: $e');
            }
          }
        }

        // Auto-admin: broadcast ROLE_CHANGED if non-host was granted admin on join
        if (!actualIsHost && actualIsAdmin && _myUid != null) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              liveKitAudioManager.sendRoomCommand(
                'ROLE_CHANGED',
                data: {
                  'userID': _myUid,
                  'newRole': 'admin',
                  'autoGrant': true,
                },
              );
            }
          });
        }
      }

      // Store join params for retry on reconnect failure
      _joinParams = {
        'token': livekitToken,
        'livekitUrl': livekitUrl,
        'iceServers': iceServers,
        'name': myDisplayName,
      };

      // ── Step 4: Connect Socket.IO & set up all event listeners ───────────
      await socketService.connect();
      // joinAudioRoom emits join(roomId, {userId, username, profile_picture})
      // matching the server's /audio-room-chat 'join' handler exactly.
      // It also stores params for auto-re-emit on reconnect.
      socketService.joinAudioRoom(
        roomId,
        userId: currentUid,
        username: myDisplayName,
        profilePicture: myPhotoUrl,
      );
      socketService.emitAudioRoom('seat_state_request'); // no args — server uses socket room context
      _setupAllSocketListeners(roomId, currentUid, hostUid);

      // ── Step 5: Start timers ───────────────────────────────────────────────
      _startHeartbeat(roomId);
      if (!actualIsHost) {
        _startHealthCheck(roomId);
      }
      if (dailyLimitMinutes > 0) {
        _startDailyLimitTimer(roomId, dailyLimitMinutes);
      }

      // ── Step 6: Host triggers recording after 3s ───────────────────────────
      if (actualIsHost && !cloudRecordingActive) {
        Future.delayed(const Duration(seconds: 3), () async {
          if (!mounted || state.roomId == null) return;
          try {
            final recRes =
                await audioRoomService.startRecording(state.roomId!);
            if (recRes['success'] == true && recRes['isHidden'] != true) {
              if (mounted) {
                state = state.copyWith(cloudRecordingActive: true);
                liveKitAudioManager.sendRoomCommand(
                  'RECORDING_STARTED',
                  data: {'isPublic': state.isRoomPublic},
                );
              }
            }
          } catch (_) {}
        });
      }

      // ── Step 7: Subscribe to participant manager events ────────────────────
      final managerSub = _participantManager.events.listen((_) {
        state = state.copyWith(
          participantProfiles: Map<String, Map<String, dynamic>>.from(
              _participantManager.profiles),
          speakers: _buildSpeakersFromSeatManager(
              state.hostUid, _myUid),
          audience: _buildAudienceFromProfiles(state.hostUid),
        );
      });
      _managerSubs.add(managerSub);

      return true;
    } catch (e) {
      if (kDebugMode) print('[AudioRoomProvider] joinRoom error: $e');
      String msg = 'Unable to join this room. Please try again.';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final serverMsg = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString()
            : null;
        final errorCode = e.response?.data is Map
            ? (e.response!.data as Map)['errorCode']?.toString()
            : null;
        if (statusCode == 426) {
          msg = 'Please update the app to join this room.';
        } else if (statusCode == 429 || errorCode == 'DAILY_LIMIT_REACHED') {
          msg = "You've used your daily Adda time for today. Come back tomorrow!";
        } else if (statusCode == 403 && errorCode == 'NOT_COMMUNITY_MEMBER') {
          msg = serverMsg ?? 'You need to join this community first.';
        } else if (statusCode == 403 && errorCode == 'COMMUNITY_MUTED') {
          msg = serverMsg ?? 'You have been muted in this community.';
        } else if (statusCode == 400 && errorCode == 'PRIVATE_ROOM') {
          msg = serverMsg ?? 'This is a private room. You need an invite link to join.';
        } else if (statusCode == 403) {
          msg = serverMsg ?? 'You are not allowed to join this room.';
        } else if (statusCode == 404) {
          msg = 'This room no longer exists.';
        } else if (statusCode == 400) {
          msg = serverMsg ?? 'This adda has ended.';
        } else if (serverMsg != null && serverMsg.isNotEmpty) {
          msg = serverMsg;
        }
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  // ── LiveKit event listener ─────────────────────────────────────────────────
  void _listenToLiveKitEvents(String myUid, String roomId) {
    final sub = liveKitAudioManager.eventStream.listen((event) {
      final eventType = event['event'] as String?;
      if (eventType == null) return;

      switch (eventType) {

        // ── Participant joined/left ─────────────────────────────────────────
        case LiveKitAudioEvents.roomUserUpdate:
          final updateType = event['updateType'] as String?;
          final userList =
              (event['userList'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (updateType == RoomUpdateType.add) {
            for (final user in userList) {
              final uid = user['userID']?.toString() ?? '';
              if (uid.isEmpty) continue;
              _participantManager.onParticipantJoined({
                'uid': uid,
                'name': user['userName']?.toString() ?? uid,
              });
              // Add to audience if not in a seat
              final seatIdx = _seatManager.getSeatForUser(uid);
              if (seatIdx == -1) {
                final updatedAudience =
                    List<Map<String, dynamic>>.from(state.audience);
                if (!updatedAudience.any((a) => a['uid'] == uid)) {
                  updatedAudience.add({
                    'uid': uid,
                    'name': user['userName']?.toString() ?? uid,
                  });
                }
                state = state.copyWith(audience: updatedAudience);
              }
            }
          } else if (updateType == RoomUpdateType.delete) {
            for (final user in userList) {
              final uid = user['userID']?.toString() ?? '';
              if (uid.isEmpty) continue;
              _participantManager.onParticipantLeft(uid);
              final updatedAudience =
                  state.audience.where((a) => a['uid'] != uid).toList();
              // Clear seat
              for (int i = 0; i < _seatManager.seats.length; i++) {
                if (_seatManager.seats[i] == uid) {
                  _seatManager.seats[i] = null;
                }
              }
              state = state.copyWith(
                audience: updatedAudience,
                speakers: _buildSpeakersFromSeatManager(
                    state.hostUid, myUid),
              );
            }
          }
          break;

        // ── Track mute / unmute ────────────────────────────────────────────
        case LiveKitAudioEvents.streamUpdate:
          final uid = event['userID']?.toString();
          final isMicOn = event['isMicOn'] as bool?;
          if (uid != null && isMicOn != null) {
            _participantManager.updateParticipantMic(uid, isMicOn);
            final updatedSpeakers = state.speakers.map((s) {
              if (s['uid'] == uid) return {...s, 'isMuted': !isMicOn};
              return s;
            }).toList();
            state = state.copyWith(speakers: updatedSpeakers);
          }
          break;

        // ── Room disconnected ──────────────────────────────────────────────
        case LiveKitAudioEvents.roomStateChanged:
          final errorCode = event['errorCode'] as int?;
          final isReconnect = event['isReconnect'] == true;
          if (errorCode == 0) {
            // Connected or Reconnected
            if (isReconnect) {
              _lastReconnectedAt = DateTime.now().millisecondsSinceEpoch;
              // Re-register in backend DB after reconnect (clears left_at)
              final rejoRole = state.isHost ? 'host' : (state.isAdmin ? 'admin' : 'audience');
              audioRoomService.joinRoom(roomId, rejoRole, reconnect: true)
                  .catchError((_) => <String, dynamic>{});
              // Re-request seat state to resync
              socketService.emitAudioRoom('seat_state_request');
            }
          } else if (errorCode == 1002034) {
            // Room deleted by host
            if (_roomClosedShown) return;
            _roomClosedShown = true;
            liveKitAudioManager.destroy().catchError((_) {});
            _showRoomEndedScreen();
          } else if (errorCode == 1002035) {
            // PARTICIPANT_REMOVED — may be spurious after reconnect
            if (_roomClosedShown) return;
            final msSinceReconnect = DateTime.now().millisecondsSinceEpoch - _lastReconnectedAt;
            final isLikelyFalseKick = msSinceReconnect < 10000;
            if (state.isHost || isLikelyFalseKick) {
              // Check room health before evicting
              audioRoomService.checkRoomHealth(roomId).then((health) async {
                if (!mounted) return;
                if (health['data']?['active'] == false) {
                  if (_roomClosedShown) return;
                  _roomClosedShown = true;
                  await liveKitAudioManager.destroy().catchError((_) {});
                  _showRoomEndedScreen();
                } else {
                  // Room alive — attempt rejoin with fresh token
                  final freshRole = state.isHost ? 'host' : (state.isAdmin ? 'admin' : 'audience');
                  audioRoomService.joinRoom(roomId, freshRole).then((joinRes) async {
                    if (!mounted) return;
                    final freshToken = joinRes['livekit_token']?.toString() ?? _joinParams?['token'] ?? '';
                    final freshUrl = joinRes['livekit_url']?.toString() ?? _joinParams?['livekitUrl'] ?? '';
                    if (freshToken.isNotEmpty && freshUrl.isNotEmpty) {
                      try {
                        await liveKitAudioManager.joinRoom(
                          roomId: roomId,
                          userId: myUid,
                          userName: _joinParams?['name'] ?? myUid,
                          token: freshToken,
                          livekitUrl: freshUrl,
                        );
                        _joinParams = {...?_joinParams, 'token': freshToken, 'livekitUrl': freshUrl};
                      } catch (_) {}
                    }
                  }).catchError((_) {});
                }
              }).catchError((_) {});
            } else {
              // Not host, not a false kick — we were kicked
              _roomClosedShown = true;
              liveKitAudioManager.stopPublishing().catchError((_) {});
              liveKitAudioManager.leaveRoom().catchError((_) {});
              audioRoomService.leaveRoom(roomId).catchError((_) => <String, dynamic>{});
              state = state.copyWith(kickedFromRoom: true);
            }
          } else if (errorCode == 1002051) {
            // Full reconnect failed — wait 4s then check health and rejoin
            final waitStartedAt = DateTime.now().millisecondsSinceEpoch;
            Future.delayed(const Duration(seconds: 4), () async {
              if (!mounted) return;
              if (_lastReconnectedAt > waitStartedAt) return; // recovered on its own
              _attemptRejoinAfterDisconnect(roomId, myUid, state.isHost ? 'host' : (state.isAdmin ? 'admin' : 'audience'));
            });
          }
          break;

        // ── My mic state changed ───────────────────────────────────────────
        case LiveKitAudioEvents.microphoneStateChanged:
          final enabled = event['enabled'] as bool? ?? false;
          state = state.copyWith(isMuted: !enabled);
          break;

        // ── LiveKit data channel roomCommands ──────────────────────────────
        case LiveKitAudioEvents.roomCommand:
          _handleRoomCommand(event, myUid);
          break;
      }
    });
    _liveKitSubs.add(sub);
  }

  // ── roomCommand handler ────────────────────────────────────────────────────
  void _handleRoomCommand(Map<String, dynamic> event, String myUid) {
    final command = event['command'] as String? ?? '';
    final targetUserId = event['targetUserId'] as String?;
    final senderId = event['senderId'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};
    final isSelfEmitted = event['isSelfEmitted'] == true;

    // Ignore commands I sent myself (except MIC_STATE_CHANGED which is a broadcast)
    if (isSelfEmitted && command != 'MIC_STATE_CHANGED') return;
    // Ignore targeted commands not directed at me (when targetUserId is set)
    if (targetUserId != null &&
        targetUserId.isNotEmpty &&
        targetUserId != myUid) return;

    switch (command) {

      case 'MIC_STATE_CHANGED':
        // Broadcast: any participant's mic state changed
        final uid = data['userID']?.toString() ?? senderId;
        final isMicOn = data['isMicOn'] == true;
        if (uid != null) {
          _participantManager.updateParticipantMic(uid, isMicOn);
          final updatedSpeakers = state.speakers.map((s) {
            if (s['uid'] == uid) return {...s, 'isMuted': !isMicOn};
            return s;
          }).toList();
          state = state.copyWith(speakers: updatedSpeakers);
        }
        break;

      case 'MUTE':
        // Host muted me
        liveKitAudioManager.setMicrophoneEnabled(false);
        state = state.copyWith(
          isMuted: true,
          mutedByHost: true,
        );
        _showAlert(
          title: 'Muted by Host',
          message: 'The host has muted your microphone.',
          type: 'info',
        );
        break;

      case 'UNMUTE_REQUEST':
        // Host is requesting I unmute — show a dialog
        _showAlert(
          title: 'Unmute Request',
          message: 'The host is asking you to unmute. Do you want to turn on your microphone?',
          type: 'info',
          confirmLabel: 'Unmute',
          onConfirm: () {
            state = state.copyWith(mutedByHost: false);
            toggleMic();
          },
          cancelLabel: 'No thanks',
        );
        break;

      case 'TURN_MIC_ON':
        // Host requests turn on my mic — show Decline / Turn On dialog (mirrors RN)
        _showAlert(
          title: 'Microphone Request',
          message: 'The host has requested you to turn on your microphone.',
          type: 'info',
          confirmLabel: 'Turn On',
          cancelLabel: 'Decline',
          onConfirm: () async {
            state = state.copyWith(mutedByHost: false);
            await liveKitAudioManager.setMicrophoneEnabled(true);
            state = state.copyWith(isMuted: false);
            if (_myUid != null) {
              _participantManager.updateParticipantMic(_myUid!, true);
              liveKitAudioManager.sendRoomCommand(
                'MIC_STATE_CHANGED',
                data: {'userID': _myUid, 'isMicOn': true},
              );
            }
          },
        );
        break;

      case 'KICK':
        // Kicked — stop audio immediately, signal navigation (no dialog)
        _roomClosedShown = true;
        liveKitAudioManager.stopPublishing().catchError((_) => null);
        liveKitAudioManager.leaveRoom().catchError((_) => null);
        audioRoomService.leaveRoom(state.roomId ?? '').catchError((_) => <String, dynamic>{});
        state = state.copyWith(kickedFromRoom: true);
        break;

      case 'BAN':
        // Banned — stop audio immediately, signal navigation
        _roomClosedShown = true;
        liveKitAudioManager.stopPublishing().catchError((_) => null);
        liveKitAudioManager.leaveRoom().catchError((_) => null);
        audioRoomService.leaveRoom(state.roomId ?? '').catchError((_) => <String, dynamic>{});
        state = state.copyWith(bannedFromRoom: true);
        break;

      case 'ROOM_CLOSED':
        // Host ended the room for everyone
        if (_roomClosedShown) return;
        _roomClosedShown = true;
        _showRoomEndedScreen();
        break;

      case 'ROLE_CHANGED':
        // My role was changed (promoted/demoted)
        final uid = data['userID']?.toString();
        final newRole = data['newRole']?.toString() ?? '';
        if (uid == null) break;
        _participantManager.onRoleUpdated(uid, newRole);
        if (uid == myUid) {
          final becameAdmin =
              newRole == 'admin' || newRole == 'host';
          state = state.copyWith(isAdmin: becameAdmin);
          if (becameAdmin) {
            _showAlert(
              title: 'You are now an Admin',
              message: 'You have been promoted to admin in this room.',
              type: 'success',
            );
          } else {
            _showAlert(
              title: 'Admin Role Removed',
              message: 'Your admin role has been removed.',
              type: 'info',
            );
          }
        } else {
          // Update admins list
          final updatedAdmins =
              List<String>.from(state.admins);
          if (newRole == 'admin' && !updatedAdmins.contains(uid)) {
            updatedAdmins.add(uid);
          } else if (newRole == 'audience') {
            updatedAdmins.remove(uid);
          }
          state = state.copyWith(admins: updatedAdmins);
        }
        break;

      case 'ROOM_NAME_CHANGED':
        final roomName = data['roomName']?.toString();
        if (roomName != null && roomName.isNotEmpty) {
          state = state.copyWith(roomName: roomName);
        }
        break;

      case 'SCREEN_SHARE_STARTED':
        final uid = data['userID']?.toString();
        final userName = data['userName']?.toString() ?? 'User';
        final streamID = data['streamID']?.toString();
        state = state.copyWith(
          screenShareInfo: {
            'uid': uid,
            'userName': userName,
            'streamID': streamID,
          },
        );
        break;

      case 'SCREEN_SHARE_STOPPED':
        state = state.copyWith(screenShareInfo: null);
        break;

      case 'CAMERA_SHARE_STARTED':
        final uid = data['userID']?.toString();
        final userName = data['userName']?.toString() ?? 'User';
        final streamID = data['streamID']?.toString();
        if (uid != null) {
          final updated =
              List<Map<String, dynamic>>.from(state.cameraShareInfos);
          if (!updated.any((c) => c['uid'] == uid)) {
            updated.add({
              'uid': uid,
              'userName': userName,
              'streamID': streamID,
            });
          }
          state = state.copyWith(cameraShareInfos: updated);
        }
        break;

      case 'CAMERA_SHARE_STOPPED':
        final uid = data['userID']?.toString();
        if (uid != null) {
          final updated = state.cameraShareInfos
              .where((c) => c['uid'] != uid)
              .toList();
          state = state.copyWith(cameraShareInfos: updated);
        }
        break;

      case 'RECORDING_STARTED':
        state = state.copyWith(cloudRecordingActive: true);
        _showAlert(
          title: 'Recording Started',
          message: 'This room is now being recorded.',
          type: 'info',
        );
        break;
    }
  }

  // ── Socket event listeners ─────────────────────────────────────────────────
  void _setupAllSocketListeners(
      String roomId, String myUid, String? hostUid) {

    // ── Chat ────────────────────────────────────────────────────────────────

    socketService.onAudioRoom('message_history', (data) {
      if (data is List) {
        final messages = data.cast<Map<String, dynamic>>();
        state = state.copyWith(chatMessages: messages);
      }
    });

    socketService.onAudioRoom('new_message', (data) {
      if (data is Map<String, dynamic>) {
        final updated =
            List<Map<String, dynamic>>.from(state.chatMessages)..add(data);
        state = state.copyWith(chatMessages: updated);
      }
    });

    socketService.onAudioRoom('message_sent', (data) {
      if (data is Map<String, dynamic>) {
        final updated =
            List<Map<String, dynamic>>.from(state.chatMessages)..add(data);
        state = state.copyWith(chatMessages: updated);
      }
    });

    socketService.onAudioRoom('message_deleted', (data) {
      if (data is Map<String, dynamic>) {
        final messageId =
            data['message_id']?.toString() ?? data['id']?.toString();
        if (messageId == null) return;
        final updated = state.chatMessages
            .where((m) =>
                m['id']?.toString() != messageId &&
                m['message_id']?.toString() != messageId)
            .toList();
        state = state.copyWith(chatMessages: updated);
      }
    });

    socketService.onAudioRoom('message_pinned', (data) {
      if (data is Map<String, dynamic>) {
        state = state.copyWith(
          pinnedMessage: data,
          pinnedLocallyDismissed: false,
        );
      }
    });

    socketService.onAudioRoom('message_unpinned', (_) {
      state = state.copyWith(pinnedMessage: null);
    });

    socketService.onAudioRoom('reaction_received', (data) {
      if (data is Map<String, dynamic>) {
        final emoji = data['emoji']?.toString() ?? '';
        final uid = data['uid']?.toString() ?? '';
        final reaction = {
          'emoji': emoji,
          'uid': uid,
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
        };
        final updated =
            List<Map<String, dynamic>>.from(state.activeReactions)
              ..add(reaction);
        state = state.copyWith(activeReactions: updated);
        // Auto-remove after 4s
        Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          final cleaned = state.activeReactions
              .where((r) => r['id'] != reaction['id'])
              .toList();
          state = state.copyWith(activeReactions: cleaned);
        });
      }
    });

    // ── Seat state (server-authoritative) ───────────────────────────────────

    socketService.onAudioRoom('seat_state', (data) {
      if (kDebugMode) print('[AudioRoomProvider] seat_state received');
      if (data is! Map<String, dynamic>) return;
      _applySeatState(data, myUid, hostUid);
    });

    socketService.onAudioRoom('seat_offstaged', (data) {
      // I was taken off stage by the host
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString();
        if (uid == myUid) {
          liveKitAudioManager.stopPublishing().catchError((_) {});
          state = state.copyWith(
            isInSeat: false,
            isSpeaker: state.isHost || state.isAdmin,
            currentSeatIndex: -1,
            isMuted: true,
            mutedByHost: false,
          );
          _showAlert(
            title: 'Moved to Audience',
            message: 'The host moved you off stage.',
            type: 'info',
          );
        }
      }
    });

    socketService.onAudioRoom('seat_request_accepted', (data) {
      // My seat request was accepted
      final acceptedUid = (data is Map) ? data['uid']?.toString() : null;
      if (acceptedUid != null && acceptedUid != myUid) return;

      final seatIndex = (data is Map)
          ? (data['seatIndex'] ?? data['seat_index'])
          : null;
      final si = seatIndex is int
          ? seatIndex
          : int.tryParse(seatIndex?.toString() ?? '') ?? -1;
      final serverAssigned = (data is Map) ? data['serverAssigned'] == true : false;

      _seatManager.clearPendingOwnRequest();
      if (si >= 0) {
        _seatManager.lockedSeats.remove(si);
        liveKitAudioManager.setSeatIndex(si);
      }
      state = state.copyWith(isHandRaised: false);

      // serverAssigned=false (legacy): server only unlocked seat, we must claim it
      if (!serverAssigned && si >= 0) {
        socketService.emitAudioRoom('seat_take', {'seatIndex': si});
      }
      // Audio start fires via seat_state confirmation
    });

    socketService.onAudioRoom('seat_request_rejected', (data) {
      final rejectedUid = (data is Map) ? data['uid']?.toString() : null;
      if (rejectedUid != null && rejectedUid != myUid) return;
      _seatManager.clearPendingOwnRequest();
      state = state.copyWith(isHandRaised: false);
      _showAlert(
        title: 'Request Declined',
        message: 'The host has declined your stage request.',
        type: 'info',
      );
    });

    socketService.onAudioRoom('seat_take_failed', (data) {
      // Seat claim failed — auto-retry on 'occupied' (mirrors RN)
      final reason = (data is Map) ? data['reason']?.toString() : null;
      if (reason == 'occupied') {
        // Check if we're already in a seat (race: seat_state arrived first)
        final alreadySeated = _seatManager.getSeatForUser(myUid) != -1;
        if (!alreadySeated) {
          final nextSeat = _seatManager.findAvailableSeat();
          if (nextSeat != -1) {
            // Silent retry with next available seat
            liveKitAudioManager.setSeatIndex(nextSeat);
            socketService.emitAudioRoom('seat_take', {'seatIndex': nextSeat});
            return;
          }
        }
        _showAlert(
          title: 'Could Not Take Seat',
          message: 'All seats are taken. Please try again later.',
          type: 'warning',
        );
      } else if (reason == 'locked') {
        _showAlert(
          title: 'Seat Locked',
          message: 'That seat is locked by the host.',
          type: 'warning',
        );
      } else {
        _showAlert(
          title: 'Could Not Take Seat',
          message: 'Could not take seat. Please try again.',
          type: 'warning',
        );
      }
    });

    socketService.onAudioRoom('seat_request_received', (data) {
      // A participant requested a seat (host view)
      if (data is Map<String, dynamic> &&
          (state.isHost || state.isAdmin)) {
        final uid = data['uid']?.toString() ?? '';
        final userName = data['name']?.toString() ??
            data['userName']?.toString() ??
            'User';
        if (uid.isEmpty) return;
        _seatManager.addSeatRequest(uid, userName);
        if (!state.handRaiseQueue.any((r) => r['uid'] == uid)) {
          final updated =
              List<Map<String, dynamic>>.from(state.handRaiseQueue)
                ..add({
                  'uid': uid,
                  'name': userName,
                  'profile_pic': data['profile_pic']?.toString(),
                });
          state = state.copyWith(handRaiseQueue: updated);
        }
      }
    });

    socketService.onAudioRoom('seat_request_cancelled', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString() ?? '';
        _seatManager.removeSeatRequest(uid);
        final updated = state.handRaiseQueue
            .where((r) => r['uid'] != uid)
            .toList();
        state = state.copyWith(handRaiseQueue: updated);
      }
    });

    socketService.onAudioRoom('seat_invite_received', (data) {
      // Host invited me to a specific seat
      if (data is Map<String, dynamic>) {
        final seatIndex = data['seat_index'] ?? data['seatIndex'];
        final si = seatIndex is int
            ? seatIndex
            : int.tryParse(seatIndex?.toString() ?? '') ?? -1;
        if (si < 0) return;
        state = state.copyWith(
          incomingSeatInvite: {'uid': myUid, 'seatIndex': si},
        );
      }
    });

    // ── Hand raise queue ─────────────────────────────────────────────────────

    socketService.onAudioRoom('hand_raise_queue', (data) {
      if (data is List) {
        final queue = data.cast<Map<String, dynamic>>();
        state = state.copyWith(handRaiseQueue: queue);
      }
    });

    socketService.onAudioRoom('hand_raise_update', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString();
        final raised = data['raised'] == true;
        if (uid == null) return;

        if (raised) {
          final exists = state.handRaiseQueue.any((r) => r['uid'] == uid);
          if (!exists) {
            final updated =
                List<Map<String, dynamic>>.from(state.handRaiseQueue)
                  ..add({
                    'uid': uid,
                    'name': data['name']?.toString() ?? uid,
                    'profile_pic': data['profile_pic']?.toString(),
                  });
            state = state.copyWith(handRaiseQueue: updated);
          }
        } else {
          final updated = state.handRaiseQueue
              .where((r) => r['uid'] != uid)
              .toList();
          state = state.copyWith(handRaiseQueue: updated);
        }
      }
    });

    // ── Participant joined / left ─────────────────────────────────────────────

    socketService.onAudioRoom('participant_joined', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString() ?? '';
        if (uid.isEmpty) return;
        _participantManager.onParticipantJoined(data);
        // Add to audience if not in a seat
        final isInSpeakers = state.speakers.any((s) => s['uid'] == uid);
        if (!isInSpeakers) {
          final updatedAudience =
              List<Map<String, dynamic>>.from(state.audience);
          if (!updatedAudience.any((a) => a['uid'] == uid)) {
            updatedAudience.add({
              'uid': uid,
              'name': data['name']?.toString() ?? uid,
              'profile_pic': data['profile_pic']?.toString(),
            });
          }
          state = state.copyWith(audience: updatedAudience);
        }
      }
    });

    socketService.onAudioRoom('participant_left', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString() ?? '';
        if (uid.isEmpty) return;
        _participantManager.onParticipantLeft(uid);
        for (int i = 0; i < _seatManager.seats.length; i++) {
          if (_seatManager.seats[i] == uid) _seatManager.seats[i] = null;
        }
        final updatedAudience =
            state.audience.where((a) => a['uid'] != uid).toList();
        // Start host departure timer if host left
        if (uid == state.hostUid && !state.isHost) {
          _startHostDepartureTimer(roomId);
        }
        state = state.copyWith(
          speakers: _buildSpeakersFromSeatManager(state.hostUid, myUid),
          audience: updatedAudience,
        );
      }
    });

    // ── Mic state ─────────────────────────────────────────────────────────────

    socketService.onAudioRoom('mic_state', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString();
        final isMicOn = data['isMicOn'] == true;
        if (uid == null) return;
        _participantManager.updateParticipantMic(uid, isMicOn);
        if (uid == myUid) {
          state = state.copyWith(isMuted: !isMicOn);
        }
        final updatedSpeakers = state.speakers.map((s) {
          if (s['uid'] == uid) return {...s, 'isMuted': !isMicOn};
          return s;
        }).toList();
        state = state.copyWith(speakers: updatedSpeakers);
      }
    });

    // ── Room ended ────────────────────────────────────────────────────────────

    socketService.onAudioRoom('room_ended', (data) {
      if (_roomClosedShown) return;
      _roomClosedShown = true;
      _showRoomEndedScreen();
    });

    // ── Bans ─────────────────────────────────────────────────────────────────

    socketService.onAudioRoom('user_banned', (data) {
      // Check if I am the one banned
      final bannedUid = (data is Map)
          ? data['banned_uid']?.toString() ?? data['uid']?.toString()
          : null;
      if (bannedUid == myUid) {
        _roomClosedShown = true;
        state = state.copyWith(error: 'You have been banned from this room.');
        leaveRoom();
      }
    });

    socketService.onAudioRoom('community_kicked', (data) {
      final targetUid = (data is Map)
          ? data['target_uid']?.toString() ?? data['uid']?.toString()
          : null;
      if (targetUid == myUid) {
        state = state.copyWith(error: 'You have been kicked from this community.');
        leaveRoom();
      }
    });

    socketService.onAudioRoom('community_banned', (data) {
      final targetUid = (data is Map)
          ? data['target_uid']?.toString() ?? data['uid']?.toString()
          : null;
      if (targetUid == myUid) {
        state = state.copyWith(
            error: 'You have been banned from this community.');
        leaveRoom();
      }
    });

    // ── Role updated ──────────────────────────────────────────────────────────

    socketService.onAudioRoom('role_updated', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString() ?? data['userID']?.toString();
        final newRole = data['role']?.toString() ?? data['newRole']?.toString() ?? '';
        if (uid == null) return;
        _participantManager.onRoleUpdated(uid, newRole);
        if (uid == myUid) {
          final becameAdmin = newRole == 'admin' || newRole == 'host';
          state = state.copyWith(isAdmin: becameAdmin);
        }
        final updatedAdmins = List<String>.from(state.admins);
        if (newRole == 'admin' && !updatedAdmins.contains(uid)) {
          updatedAdmins.add(uid);
        } else if (newRole == 'audience') {
          updatedAdmins.remove(uid);
        }
        state = state.copyWith(admins: updatedAdmins);
      }
    });

    // ── Admin actions (platform admin events) ─────────────────────────────────

    socketService.onAudioRoom('admin_action', (data) {
      if (data is! Map<String, dynamic>) return;
      final action = data['action']?.toString() ?? '';
      switch (action) {
        case 'freeze_close':
          state = state.copyWith(closeFrozen: true);
          break;
        case 'unfreeze_close':
          state = state.copyWith(closeFrozen: false);
          break;
        case 'freeze_actions':
          state = state.copyWith(actionsFrozen: true);
          break;
        case 'unfreeze_actions':
          state = state.copyWith(actionsFrozen: false);
          break;
        case 'rename':
          final newName = data['room_name']?.toString();
          if (newName != null && newName.isNotEmpty) {
            state = state.copyWith(roomName: newName);
          }
          break;
        case 'admin_mute':
          if (data['target_uid']?.toString() == myUid) {
            liveKitAudioManager.setMicrophoneEnabled(false);
            state = state.copyWith(isMuted: true, mutedByHost: true);
          }
          break;
        case 'admin_unmute':
          if (data['target_uid']?.toString() == myUid) {
            state = state.copyWith(mutedByHost: false);
          }
          break;
        case 'offstage':
          if (data['target_uid']?.toString() == myUid) {
            liveKitAudioManager.stopPublishing().catchError((_) {});
            state = state.copyWith(
              isInSeat: false,
              isSpeaker: state.isHost || state.isAdmin,
              currentSeatIndex: -1,
              isMuted: true,
            );
          }
          break;
      }
    });

    // ── YouTube watch-together ────────────────────────────────────────────────

    socketService.onAudioRoom('yt_change', (data) {
      if (data is Map<String, dynamic>) {
        final videoId = data['videoId']?.toString();
        final timestamp = (data['timestamp'] as num?)?.toDouble() ?? 0.0;
        state = state.copyWith(
          youtubeVideoId: videoId,
          youtubeIsPlaying: true,
          youtubeIsBuffering: true,
          youtubeCurrentTime: timestamp,
          showYoutubeSection: videoId != null,
        );
      }
    });

    socketService.onAudioRoom('yt_play', (data) {
      if (data is Map<String, dynamic>) {
        final timestamp = (data['timestamp'] as num?)?.toDouble() ?? 0.0;
        state = state.copyWith(
          youtubeIsPlaying: true,
          youtubeCurrentTime: timestamp,
        );
      }
    });

    socketService.onAudioRoom('yt_pause', (data) {
      if (data is Map<String, dynamic>) {
        final timestamp = (data['timestamp'] as num?)?.toDouble() ??
            state.youtubeCurrentTime;
        state = state.copyWith(
          youtubeIsPlaying: false,
          youtubeCurrentTime: timestamp,
        );
      }
    });

    socketService.onAudioRoom('yt_seek', (data) {
      if (data is Map<String, dynamic>) {
        final timestamp = (data['timestamp'] as num?)?.toDouble() ?? 0.0;
        state = state.copyWith(youtubeCurrentTime: timestamp);
      }
    });

    socketService.onAudioRoom('yt_stop', (_) {
      state = state.copyWith(
        youtubeVideoId: null,
        youtubeIsPlaying: false,
        youtubeIsBuffering: false,
        youtubeCurrentTime: 0.0,
        youtubeDuration: 0.0,
        showYoutubeSection: false,
      );
    });
  }

  // ── _applySeatState ────────────────────────────────────────────────────────
  void _applySeatState(
      Map<String, dynamic> payload, String myUid, String? hostUid) {
    final seats = payload['seats'] as List?;
    if (seats == null) return;

    final maxSeats = (payload['maxSeats'] as int?) ??
        (payload['max_seats'] as int?) ??
        state.maxSeats;

    final newSeats = List<String?>.filled(maxSeats, null);
    for (int i = 0; i < seats.length && i < maxSeats; i++) {
      newSeats[i] = seats[i]?.toString();
    }

    // Locked seats
    final lockedRaw = payload['lockedSeats'] ?? payload['locked_seats'];
    final Set<int> newLockedSeats = lockedRaw is List
        ? Set<int>.from(lockedRaw.map((e) => e as int? ?? 0))
        : {};

    // Participants in payload
    final participants = payload['participants'] as List?;
    if (participants != null) {
      for (final p in participants) {
        if (p is! Map<String, dynamic>) continue;
        final uid = p['uid']?.toString() ?? p['user_id']?.toString();
        if (uid == null) continue;
        _participantManager.onParticipantJoined({
          'uid': uid,
          'name': p['name']?.toString() ?? 'User',
          'profile_pic': p['profile_pic']?.toString(),
          'isHost': p['role'] == 'host' || uid == hostUid,
          'isAdmin': p['role'] == 'admin' || p['role'] == 'host',
        });
      }
    }

    // Apply to seat manager
    _seatManager.applySeatState(
      newSeats: newSeats,
      newLockedSeats: newLockedSeats,
      newMaxSeats: maxSeats,
    );

    // stageRequestEnabled
    final sre = payload['stageRequestEnabled'] ??
        payload['stage_request_enabled'];
    final stageRequestEnabled = sre == null
        ? state.stageRequestEnabled
        : (sre == true || sre == 1);

    // Am I now in a seat?
    final mySeat = newSeats.indexOf(myUid);
    final wasInSeat = state.isInSeat;
    final nowInSeat = mySeat >= 0;

    // Placed in a seat → start publishing
    if (nowInSeat && !wasInSeat && !liveKitAudioManager.isPublishing) {
      _onSeatAssigned(mySeat, myUid);
    }
    // Removed from seat → stop publishing
    if (!nowInSeat && wasInSeat && liveKitAudioManager.isPublishing) {
      liveKitAudioManager.stopPublishing().catchError((_) {});
    }

    // Fetch missing profiles for newly seated UIDs
    final seatedUids = newSeats.whereType<String>().toList();
    _participantManager.fetchMissingSeatedProfiles(seatedUids);

    state = state.copyWith(
      speakers: _buildSpeakersFromSeatManager(hostUid, myUid),
      audience: _buildAudienceFromProfiles(hostUid),
      maxSeats: maxSeats,
      stageRequestEnabled: stageRequestEnabled,
      currentSeatIndex: mySeat,
      isInSeat: nowInSeat,
      isSpeaker: nowInSeat || state.isHost || state.isAdmin,
      lockedSeats: newLockedSeats,
      seatsInitialized: true,
      participantProfiles: Map<String, Map<String, dynamic>>.from(
          _participantManager.profiles),
    );
  }

  // ── _buildSpeakersFromSeatManager ─────────────────────────────────────────
  List<Map<String, dynamic>> _buildSpeakersFromSeatManager(
      String? hostUid, String? myUid) {
    return _seatManager.seats.asMap().entries.map((entry) {
      final idx = entry.key;
      final uid = entry.value;
      if (uid == null) {
        return <String, dynamic>{
          'seatIndex': idx,
          'isEmpty': true,
          'isLocked': _seatManager.isSeatLocked(idx),
        };
      }
      final profile = _participantManager.getProfile(uid) ?? {};
      final avatarUrl = profile['avatar']?.toString() ??
          profile['profile_pic']?.toString() ??
          profile['profile_pic_medium']?.toString();
      return <String, dynamic>{
        'seatIndex': idx,
        'isEmpty': false,
        'uid': uid,
        'name': profile['name']?.toString() ?? 'User',
        'profile_pic': avatarUrl,
        'avatar': avatarUrl,
        'isHost': uid == hostUid || profile['isHost'] == true,
        'isAdmin': profile['isAdmin'] == true,
        'isMuted': profile['isMuted'] != false,
        'isVerified': profile['isVerified'] == true,
        'verificationBadge': profile['verificationBadge'],
        'avatarFrameUrl': profile['avatarFrameUrl']?.toString(),
        'isSelf': uid == myUid,
        'soundLevel': profile['soundLevel'] ?? 0.0,
      };
    }).toList();
  }

  // ── _buildAudienceFromProfiles ──────────────────────────────────────────────
  List<Map<String, dynamic>> _buildAudienceFromProfiles(String? hostUid) {
    final seatedUids = _seatManager.seats.whereType<String>().toSet();
    final result = <Map<String, dynamic>>[];

    _participantManager.profiles.forEach((uid, profile) {
      if (uid == hostUid || profile['isHost'] == true) return;
      if (seatedUids.contains(uid)) return;

      final avatarUrl = profile['avatar']?.toString() ??
          profile['profile_pic']?.toString() ??
          profile['profile_pic_medium']?.toString();
      final name = profile['name']?.toString() ?? 'User';

      result.add({
        'uid': uid,
        'name': name,
        'userName': name,
        'profile_pic': avatarUrl,
        'avatar': avatarUrl,
        'avatarFrameUrl': profile['avatarFrameUrl']?.toString(),
        'isVerified': profile['isVerified'] == true,
        'isAdmin': profile['isAdmin'] == true,
      });
    });

    return result;
  }

  // ── _onSeatAssigned ────────────────────────────────────────────────────────
  Future<void> _onSeatAssigned(int seatIndex, String myUid) async {
    if (kDebugMode) {
      print('[AudioRoomProvider] Assigned to seat $seatIndex — starting audio');
    }
    try {
      await liveKitAudioManager.waitForRoomConnection(timeoutMs: 8000);
      await liveKitAudioManager.startPublishing();
      // Start muted per RN behaviour — user unmutes manually
      await liveKitAudioManager.setMicrophoneEnabled(false);
      state = state.copyWith(
          isMuted: true, isSpeaker: true, currentSeatIndex: seatIndex);
    } catch (e) {
      if (kDebugMode) {
        print('[AudioRoomProvider] _onSeatAssigned failed: $e');
      }
    }
  }

  // ── _showRoomEndedScreen ───────────────────────────────────────────────────
  Future<void> _showRoomEndedScreen() async {
    // If current user is the host, just navigate back — no "ended" screen
    if (state.isHost || _myUid == state.hostUid) {
      await _cleanupOnLeave();
      state = state.copyWith(shouldNavigateBack: true);
      return;
    }

    // Try to fetch host profile for the ended screen
    Map<String, dynamic>? hostProfile;
    if (state.hostUid != null) {
      try {
        hostProfile =
            await audioRoomService.getUserProfile(state.hostUid!);
      } catch (_) {}
    }
    await _cleanupOnLeave();
    state = state.copyWith(
      showRoomEndedScreen: true,
      hostProfileForEndedScreen: hostProfile,
    );
  }

  // ── Host departure timer ───────────────────────────────────────────────────
  void _startHostDepartureTimer(String roomId) {
    _hostDepartureTimer?.cancel();
    // Give the host 5 minutes to reconnect before we check health
    _hostDepartureTimer =
        Timer(const Duration(minutes: 5), () async {
      try {
        final health = await audioRoomService.checkRoomHealth(roomId);
        if (health['data']?['active'] == false) {
          if (_roomClosedShown) return;
          _roomClosedShown = true;
          _showRoomEndedScreen();
        }
      } catch (_) {}
    });
  }

  // ── Health check (non-host, every 90s) ────────────────────────────────────
  void _startHealthCheck(String roomId) {
    // Jitter: 0-29s per RN logic
    final jitterMs = (roomId.codeUnits.fold(0, (a, b) => a + b) % 30) * 1000;
    Future.delayed(Duration(milliseconds: jitterMs), () {
      if (!mounted) return;
      _healthCheckTimer?.cancel();
      _healthCheckTimer = Timer.periodic(
        const Duration(seconds: 90),
        (_) async {
          if (_hostDepartureTimer != null) return; // grace period active
          try {
            final health =
                await audioRoomService.checkRoomHealth(roomId);
            if (health['data']?['active'] == false) {
              if (_roomClosedShown) return;
              _roomClosedShown = true;
              _healthCheckTimer?.cancel();
              await liveKitAudioManager.destroy();
              try { await audioRoomService.leaveRoom(roomId); } catch (_) {}
              _showRoomEndedScreen();
            }
          } catch (e) {
            // 400/404 = room ended
            if (e is DioException) {
              final code = e.response?.statusCode;
              if (code == 400 || code == 404) {
                if (_roomClosedShown) return;
                _roomClosedShown = true;
                _healthCheckTimer?.cancel();
                _showRoomEndedScreen();
              }
            }
          }
        },
      );
    });
  }

  // ── Rejoin after 1002051 disconnect ─────────────────────────────────────
  Future<void> _attemptRejoinAfterDisconnect(
      String roomId, String myUid, String role) async {
    if (!mounted || _roomClosedShown) return;
    try {
      final health = await audioRoomService.checkRoomHealth(roomId);
      if (!mounted) return;
      if (health['data']?['active'] == false) {
        if (_roomClosedShown) return;
        _roomClosedShown = true;
        await liveKitAudioManager.destroy().catchError((_) {});
        _showRoomEndedScreen();
        return;
      }
      // Room alive — get fresh token and rejoin
      final joinRes = await audioRoomService.joinRoom(roomId, role);
      if (!mounted) return;
      if (joinRes['success'] != true) {
        if (_roomClosedShown) return;
        _roomClosedShown = true;
        await liveKitAudioManager.destroy().catchError((_) {});
        _showRoomEndedScreen();
        return;
      }
      final freshToken = joinRes['livekit_token']?.toString() ?? _joinParams?['token'] ?? '';
      final freshUrl = joinRes['livekit_url']?.toString() ?? _joinParams?['livekitUrl'] ?? '';
      if (freshToken.isNotEmpty && freshUrl.isNotEmpty) {
        await liveKitAudioManager.joinRoom(
          roomId: roomId,
          userId: myUid,
          userName: _joinParams?['name'] ?? myUid,
          token: freshToken,
          livekitUrl: freshUrl,
        );
        _joinParams = {...?_joinParams, 'token': freshToken, 'livekitUrl': freshUrl};
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final s = e.response?.statusCode;
      if (s == 400 || s == 404) {
        if (_roomClosedShown) return;
        _roomClosedShown = true;
        await liveKitAudioManager.destroy().catchError((_) {});
        _showRoomEndedScreen();
      }
      // For other errors: schedule retry with backoff
    } catch (_) {}
  }

  // ── Heartbeat (30s) ───────────────────────────────────────────────────────
  void _startHeartbeat(String roomId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => socketService.emitAudioRoom('heartbeat'),
    );
  }

  // ── Daily limit ticker ────────────────────────────────────────────────────
  void _startDailyLimitTimer(String roomId, int limitMinutes) {
    _dailyLimitTimer?.cancel();
    final limitSec = limitMinutes * 60;
    _dailyLimitTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _dailySpentSecondsLocal += 1;
      state = state.copyWith(
          dailySpentSeconds: _dailySpentSecondsLocal);
      if (_dailySpentSecondsLocal >= limitSec && !_timeLimitFired) {
        _timeLimitFired = true;
        _dailyLimitTimer?.cancel();
        await leaveRoom();
        state = state.copyWith(
            error: 'You have used up your Personal Adda time for today.');
      }
    });
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  Future<void> _cleanupOnLeave() async {
    _heartbeatTimer?.cancel();
    _healthCheckTimer?.cancel();
    _hostDepartureTimer?.cancel();
    _dailyLimitTimer?.cancel();
    _reactionCleanupTimer?.cancel();
    _reactionCooldownTimer?.cancel();
    for (final sub in _liveKitSubs) {
      sub.cancel();
    }
    _liveKitSubs.clear();
    for (final sub in _managerSubs) {
      sub.cancel();
    }
    _managerSubs.clear();
    _removeSocketListeners();
    _participantManager.dispose();
    _seatManager.dispose();
  }

  // ── leaveRoom ──────────────────────────────────────────────────────────────
  Future<void> leaveRoom() async {
    final roomId = state.roomId;
    await _cleanupOnLeave();

    if (roomId != null) {
      socketService.leaveAudioRoom(roomId); // clears stored join params + emits leave_room
    }

    if (roomId != null) {
      try { await audioRoomService.leaveRoom(roomId); } catch (_) {}
    }

    await liveKitAudioManager.leaveRoom();

    state = const AudioRoomState();
  }

  void _removeSocketListeners() {
    socketService.offAudioRoom('message_history');
    socketService.offAudioRoom('new_message');
    socketService.offAudioRoom('message_sent');
    socketService.offAudioRoom('message_deleted');
    socketService.offAudioRoom('message_pinned');
    socketService.offAudioRoom('message_unpinned');
    socketService.offAudioRoom('reaction_received');
    socketService.offAudioRoom('seat_state');
    socketService.offAudioRoom('seat_offstaged');
    socketService.offAudioRoom('seat_request_accepted');
    socketService.offAudioRoom('seat_request_rejected');
    socketService.offAudioRoom('seat_take_failed');
    socketService.offAudioRoom('seat_request_received');
    socketService.offAudioRoom('seat_request_cancelled');
    socketService.offAudioRoom('seat_invite_received');
    socketService.offAudioRoom('hand_raise_queue');
    socketService.offAudioRoom('hand_raise_update');
    socketService.offAudioRoom('participant_joined');
    socketService.offAudioRoom('participant_left');
    socketService.offAudioRoom('mic_state');
    socketService.offAudioRoom('room_ended');
    socketService.offAudioRoom('user_banned');
    socketService.offAudioRoom('community_kicked');
    socketService.offAudioRoom('community_banned');
    socketService.offAudioRoom('role_updated');
    socketService.offAudioRoom('admin_action');
    socketService.offAudioRoom('yt_change');
    socketService.offAudioRoom('yt_play');
    socketService.offAudioRoom('yt_pause');
    socketService.offAudioRoom('yt_seek');
    socketService.offAudioRoom('yt_stop');
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Mic ────────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════

  Future<void> toggleMic() async {
    if (state.isMicLoading) return;

    // Only users in seats (or host) can toggle mic
    if (!state.isInSeat && !state.isHost) {
      _showAlert(
        title: 'Cannot Use Microphone',
        message: 'You need to take a speaker seat to use your microphone.',
        type: 'warning',
      );
      return;
    }

    // Cannot unmute if muted by host
    final newMicOn = state.isMuted;
    if (newMicOn && state.mutedByHost) {
      _showAlert(
        title: 'Cannot Unmute',
        message: 'You were muted by the host. Only the host can unmute you.',
        type: 'warning',
      );
      return;
    }

    state = state.copyWith(isMicLoading: true);
    try {
      await liveKitAudioManager.setMicrophoneEnabled(newMicOn);
      if (!newMicOn) {
        // Self-muting clears the mutedByHost flag
        state = state.copyWith(mutedByHost: false);
      }
      state = state.copyWith(isMuted: !newMicOn, isMicLoading: false);

      // Broadcast mic state to all participants via LiveKit data channel
      if (_myUid != null) {
        _participantManager.updateParticipantMic(_myUid!, newMicOn);
        liveKitAudioManager.sendRoomCommand(
          'MIC_STATE_CHANGED',
          targetUserId: null, // broadcast
          data: {
            'userID': _myUid,
            'isMicOn': newMicOn,
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('[AudioRoomProvider] toggleMic error: $e');
      state = state.copyWith(isMicLoading: false);
      _showAlert(
        title: 'Error',
        message: 'Failed to toggle microphone.',
        type: 'danger',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Seat actions ───────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  void takeSeat(int seatIndex) {
    // Guards: must be initialized and connected (mirrors RN handleEmptySeatPress)
    if (!state.seatsInitialized) return;
    if (!liveKitAudioManager.isConnected) return;
    if (!state.canTakeAddaSeat) return;

    // If already in a seat, this is a seat-change (5s cooldown)
    final currentSeat = _seatManager.getSeatForUser(_myUid ?? '');
    if (currentSeat != -1) {
      changeSeat(currentSeat, seatIndex);
      return;
    }

    liveKitAudioManager.setSeatIndex(seatIndex);
    socketService.emitAudioRoom('seat_take', {'seatIndex': seatIndex});
  }

  void changeSeat(int fromIndex, int toIndex) {
    // 5-second cooldown between seat changes (mirrors RN lastSeatChangeTimeRef)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSeatChangeTime < 5000) return;
    _lastSeatChangeTime = now;

    liveKitAudioManager.setSeatIndex(toIndex);
    socketService.emitAudioRoom('seat_change', {
      'fromIndex': fromIndex,
      'toIndex': toIndex,
    });
  }

  void removeGhostFromSeat(String uid) {
    // Host removes a disconnected ghost user from a seat (mirrors RN seat_remove)
    socketService.emitAudioRoom('seat_remove', {'targetUid': uid});
  }

  Future<void> leaveSeat() async {
    socketService.emitAudioRoom('seat_leave'); // no args — server uses socket room context
    await liveKitAudioManager.stopPublishing().catchError((_) => null);
    state = state.copyWith(
      isInSeat: false,
      isSpeaker: state.isHost || state.isAdmin,
      currentSeatIndex: -1,
      isHandRaised: false,
      isMuted: true,
      mutedByHost: false,
    );
  }

  void toggleHandRaise() {
    if (state.isInSeat) return; // Already on stage
    final nextState = !state.isHandRaised;
    state = state.copyWith(isHandRaised: nextState);
    if (nextState) {
      _seatManager.setPendingOwnRequest();
      // Server determines seat assignment; pass seatIndex=-1 to let it pick
      socketService.emitAudioRoom('seat_request', {'seatIndex': -1});
    } else {
      _seatManager.clearPendingOwnRequest();
      // No server cancel event — server infers cancellation from disconnect/re-join
      // Just clear local state; the host will see the request disappear on next seat_state
    }
  }

  void toggleSeatLock(int seatIndex) {
    if (state.roomId == null) return;
    final isLocked = state.lockedSeats.contains(seatIndex);
    final updatedLocked = Set<int>.from(state.lockedSeats);
    if (isLocked) {
      updatedLocked.remove(seatIndex);
    } else {
      updatedLocked.add(seatIndex);
    }
    state = state.copyWith(lockedSeats: updatedLocked);
    // Server uses separate seat_lock / seat_unlock events (mirrors RN)
    if (isLocked) {
      socketService.emitAudioRoom('seat_unlock', {'seatIndex': seatIndex});
    } else {
      socketService.emitAudioRoom('seat_lock', {'seatIndex': seatIndex});
    }
  }

  void acceptSeatInvite() {
    final invite = state.incomingSeatInvite;
    if (invite == null) return;
    final si = invite['seatIndex'] as int? ?? -1;
    if (si < 0) return;
    socketService.emitAudioRoom('seat_invite_accept', {'seatIndex': si});
    state = state.copyWith(incomingSeatInvite: null);
  }

  void declineSeatInvite() {
    state = state.copyWith(incomingSeatInvite: null);
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Host / Admin controls ──────────────────────────────════════════
  // ══════════════════════════════════════════════════════════════════

  void acceptSeatRequest(String uid) {
    // RN server uses seat_request_accept with targetUid + optional seatIndex
    final req = state.handRaiseQueue.firstWhere(
      (r) => r['uid'] == uid,
      orElse: () => <String, dynamic>{},
    );
    socketService.emitAudioRoom('seat_request_accept', {
      'targetUid': uid,
      if (req['seatIndex'] != null) 'seatIndex': req['seatIndex'],
    });
    _seatManager.removeSeatRequest(uid);
    final updated =
        state.handRaiseQueue.where((r) => r['uid'] != uid).toList();
    state = state.copyWith(handRaiseQueue: updated);
  }

  void rejectSeatRequest(String uid) {
    socketService.emitAudioRoom('seat_request_reject', {'targetUid': uid});
    _seatManager.removeSeatRequest(uid);
    final updated =
        state.handRaiseQueue.where((r) => r['uid'] != uid).toList();
    state = state.copyWith(handRaiseQueue: updated);
  }

  void inviteToSeat(String uid, int seatIndex) {
    socketService.emitAudioRoom('seat_invite', {
      'targetUid': uid,
      'seatIndex': seatIndex,
    });
  }

  void moveParticipantToSeat(String uid, int seatIndex) {
    socketService.emitAudioRoom('host_move_seat', {
      'targetUid': uid,
      'seatIndex': seatIndex,
    });
  }

  void offStageParticipant(String uid) {
    socketService.emitAudioRoom('seat_offstage', {'targetUid': uid});
  }

  Future<void> muteParticipant(String uid) async {
    // Send MUTE via LiveKit data channel (mirrors RN)
    await liveKitAudioManager.sendRoomCommand(
      'MUTE',
      targetUserId: uid,
      data: {'userID': uid},
    );
  }

  Future<void> requestUnmute(String uid) async {
    await liveKitAudioManager.sendRoomCommand(
      'UNMUTE_REQUEST',
      targetUserId: uid,
      data: {'userID': uid},
    );
  }

  Future<void> kickParticipant(String uid) async {
    socketService.emitAudioRoom('user_kicked', {
      'kicked_uid': uid,
      'kicked_name': _participantManager.getDisplayName(uid),
    });
    await liveKitAudioManager.sendRoomCommand(
      'KICK',
      targetUserId: uid,
      data: {'userID': uid},
    );
    try { await audioRoomService.kickUser(state.roomId!, uid); } catch (_) {}
  }

  Future<void> banParticipant(String uid) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    await audioRoomService.banParticipant(roomId, uid);
    await liveKitAudioManager.sendRoomCommand(
      'BAN',
      targetUserId: uid,
      data: {'userID': uid},
    );
    socketService.emitAudioRoom('user_banned', {
      'banned_uid': uid,
      'banned_name': _participantManager.getDisplayName(uid),
    });
  }

  Future<void> communityKick(String uid, String userName, {String? reason}) async {
    socketService.emitAudioRoom('community_kick', {
      'target_uid': uid,
      'target_name': userName,
      if (reason != null) 'reason': reason,
    });
    // Immediately kick from adda via LiveKit
    await liveKitAudioManager.sendRoomCommand(
      'KICK',
      targetUserId: uid,
      data: {'userID': uid},
    );
  }

  Future<void> communityBan(String uid, String userName, {String? reason}) async {
    socketService.emitAudioRoom('community_ban', {
      'target_uid': uid,
      'target_name': userName,
      if (reason != null) 'reason': reason,
    });
    await liveKitAudioManager.sendRoomCommand(
      'KICK',
      targetUserId: uid,
      data: {'userID': uid},
    );
  }

  Future<void> promoteAdmin(String uid) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    final res = await audioRoomService.promoteAdmin(roomId, uid);
    if (res['success'] == true) {
      final updated = List<String>.from(state.admins);
      if (!updated.contains(uid)) updated.add(uid);
      state = state.copyWith(admins: updated);
      _participantManager.onRoleUpdated(uid, 'admin');
      await liveKitAudioManager.sendRoomCommand(
        'ROLE_CHANGED',
        targetUserId: uid,
        data: {'userID': uid, 'newRole': 'admin'},
      );
    }
  }

  Future<void> demoteAdmin(String uid) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    final res = await audioRoomService.removeAdminRole(roomId, uid);
    if (res['success'] == true) {
      final updated =
          state.admins.where((a) => a != uid).toList();
      state = state.copyWith(admins: updated);
      _participantManager.onRoleUpdated(uid, 'audience');
      await liveKitAudioManager.sendRoomCommand(
        'ROLE_CHANGED',
        targetUserId: uid,
        data: {'userID': uid, 'newRole': 'audience'},
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Room lifecycle ─────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  Future<void> endRoom() async {
    final roomId = state.roomId;
    if (roomId == null) return;

    // Stop YouTube if active
    if (state.youtubeVideoId != null) {
      socketService.emitAudioRoom('yt_stop', {'roomId': roomId});
    }

    // Broadcast ROOM_CLOSED to all participants
    try {
      await liveKitAudioManager.sendRoomCommand(
        'ROOM_CLOSED',
        data: {'message': 'The host has ended this room'},
      );
    } catch (_) {}

    await audioRoomService.endRoom(roomId);
    await liveKitAudioManager.destroy();
    await leaveRoom();
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Room settings ──────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  Future<void> renameRoom(String newName) async {
    final roomId = state.roomId;
    if (roomId == null || newName.isEmpty) return;
    try {
      await audioRoomService.updateRoom(roomId, {'room_name': newName});
      await liveKitAudioManager.sendRoomCommand(
        'ROOM_NAME_CHANGED',
        data: {'roomName': newName},
      );
      state = state.copyWith(roomName: newName);
    } catch (e) {
      if (kDebugMode) print('[AudioRoomProvider] renameRoom error: $e');
    }
  }

  Future<void> toggleCoolDownMode(bool enabled) async {
    state = state.copyWith(coolDownMode: enabled);
    try {
      await audioRoomService.toggleCoolDownMode(state.roomId!, enabled);
    } catch (_) {
      state = state.copyWith(coolDownMode: !enabled); // revert
    }
  }

  Future<void> toggleStageRequest(bool enabled) async {
    state = state.copyWith(stageRequestEnabled: enabled);
    _seatManager.stageRequestEnabled = enabled;
    try {
      if (enabled) {
        socketService.emitAudioRoom('seat_lock_all'); // no args
      } else {
        socketService.emitAudioRoom('seat_unlock_all'); // no args
      }
      await audioRoomService.updateStageRequestEnabled(
          state.roomId!, enabled);
    } catch (_) {
      state = state.copyWith(stageRequestEnabled: !enabled); // revert
    }
  }

  Future<void> expandSeats() async {
    final roomId = state.roomId;
    if (roomId == null) return;
    final newMax = (state.maxSeats + 1).clamp(1, 20);
    if (newMax == state.maxSeats) return;
    state = state.copyWith(maxSeats: newMax);
    _seatManager.maxSeats = newMax;
    try { await audioRoomService.updateSeatCount(roomId, newMax); } catch (_) {}
  }

  Future<void> collapseSeats() async {
    final roomId = state.roomId;
    if (roomId == null) return;
    // Cannot collapse below number of occupied seats
    final occupied =
        _seatManager.seats.where((s) => s != null).length;
    final newMax = (state.maxSeats - 1).clamp(occupied, 20);
    if (newMax == state.maxSeats) return;
    state = state.copyWith(maxSeats: newMax);
    _seatManager.maxSeats = newMax;
    try { await audioRoomService.updateSeatCount(roomId, newMax); } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Chat ──────────────────────────────────────────────════════════
  // ══════════════════════════════════════════════════════════════════

  void sendChatMessage(String text, {Map<String, dynamic>? replyTo}) {
    if (text.trim().isEmpty) return;
    // Server expects: { room_id, content, reply_to_id?, reply_to_username?, reply_to_content? }
    socketService.emitAudioRoom('send_message', {
      'room_id': state.roomId,
      'content': text.trim(),
      if (replyTo != null) ...{
        'reply_to_id': replyTo['id'],
        'reply_to_username': replyTo['senderName'] ?? replyTo['sender_username'],
        'reply_to_content': replyTo['text'] ?? replyTo['content'],
      },
    });
    if (state.replyingTo != null) {
      state = state.copyWith(replyingTo: null);
    }
  }

  void deleteMessage(String messageId) {
    // Server expects: { message_id }
    socketService.emitAudioRoom('delete_message', {'message_id': messageId});
  }

  void pinMessage(String messageId) {
    // Server expects: { message_id }
    socketService.emitAudioRoom('pin_message', {'message_id': messageId});
  }

  void unpinMessage() {
    // Server expects no body (room context from join)
    socketService.emitAudioRoom('unpin_message', {});
  }

  void dismissPinnedMessage() {
    state = state.copyWith(pinnedLocallyDismissed: true);
  }

  void setReplyingTo(Map<String, dynamic>? message) {
    state = state.copyWith(replyingTo: message);
  }

  void dismissRulesBanner() {
    state = state.copyWith(rulesDismissed: true);
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Reactions ────────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  void sendReaction(String emoji) {
    if (_reactionOnCooldown) return;
    socketService.emitAudioRoom(
        'send_reaction', {'roomId': state.roomId, 'emoji': emoji});
    // 10-second cooldown per RN behaviour
    _reactionOnCooldown = true;
    _reactionCooldownTimer?.cancel();
    _reactionCooldownTimer = Timer(
      const Duration(seconds: 10),
      () => _reactionOnCooldown = false,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ── YouTube ──────────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  void selectYoutubeVideo(String videoId) {
    state = state.copyWith(
      youtubeVideoId: videoId,
      youtubeIsPlaying: true,
      youtubeIsBuffering: true,
      youtubeCurrentTime: 0.0,
      youtubeDuration: 0.0,
      showYoutubeSection: true,
    );
    socketService.emitAudioRoom('yt_change', {
      'roomId': state.roomId,
      'videoId': videoId,
      'timestamp': 0,
      'startedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void playYoutube(double timestamp) {
    state = state.copyWith(youtubeIsPlaying: true, youtubeCurrentTime: timestamp);
    if (state.isHost) {
      socketService.emitAudioRoom('yt_play', {
        'roomId': state.roomId,
        'timestamp': timestamp,
        'startedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  void pauseYoutube(double timestamp) {
    state = state.copyWith(youtubeIsPlaying: false, youtubeCurrentTime: timestamp);
    if (state.isHost) {
      socketService.emitAudioRoom(
          'yt_pause', {'roomId': state.roomId, 'timestamp': timestamp});
    }
  }

  void seekYoutube(double timestamp) {
    state = state.copyWith(youtubeCurrentTime: timestamp);
    if (state.isHost) {
      socketService.emitAudioRoom(
          'yt_seek', {'roomId': state.roomId, 'timestamp': timestamp});
    }
  }

  void stopYoutube() {
    socketService.emitAudioRoom('yt_stop', {'roomId': state.roomId});
    state = state.copyWith(
      youtubeVideoId: null,
      youtubeIsPlaying: false,
      youtubeIsBuffering: false,
      youtubeCurrentTime: 0.0,
      youtubeDuration: 0.0,
      showYoutubeSection: false,
    );
  }

  void updateYoutubeTime(double time) {
    state = state.copyWith(youtubeCurrentTime: time);
  }

  void setYoutubeBuffering(bool buffering) {
    state = state.copyWith(youtubeIsBuffering: buffering);
  }

  // ══════════════════════════════════════════════════════════════════
  // ── Audio output ─────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  Future<void> setAudioOutputMode(String mode) async {
    state = state.copyWith(audioOutputMode: mode);
    try {
      await liveKitAudioManager.setAudioOutputMode(mode);
    } catch (e) {
      if (kDebugMode) print('[AudioRoomProvider] setAudioOutputMode error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ── UI helpers ────────────────────────────────────════════════════
  // ══════════════════════════════════════════════════════════════════

  void toggleMinimised() {
    state = state.copyWith(isMinimised: !state.isMinimised);
  }

  void minimizeRoom() {
    state = state.copyWith(isMinimised: true);
  }

  void restoreRoom() {
    state = state.copyWith(isMinimised: false);
    // Re-request seat state to resync after restore
    if (state.roomId != null) {
      socketService.emitAudioRoom('seat_state_request');
    }
  }

  void showLeaveDialog(Map<String, dynamic> config) {
    state = state.copyWith(leaveDialogConfig: config, showLeaveDialog: true);
  }

  void hideLeaveDialog() {
    state = state.copyWith(showLeaveDialog: false);
  }

  void hideAlertDialog() {
    state = state.copyWith(showAlertDialog: false, alertDialogConfig: null);
  }

  void _showAlert({
    required String title,
    required String message,
    String type = 'info',
    String? confirmLabel,
    String? cancelLabel,
    void Function()? onConfirm,
    void Function()? onCancel,
  }) {
    state = state.copyWith(
      alertDialogConfig: {
        'title': title,
        'message': message,
        'type': type,
        'confirmLabel': confirmLabel ?? 'OK',
        'cancelLabel': cancelLabel,
        'onConfirm': onConfirm,
        'onCancel': onCancel,
      },
      showAlertDialog: true,
    );
  }

  // ── Rating ─────────────────────────────────────────────────────────────────
  Future<void> submitRating(int rating, {String? review}) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    try {
      await audioRoomService.submitRating(roomId, rating, review: review);
      state = state.copyWith(hasRated: true);
    } catch (e) {
      if (kDebugMode) print('[AudioRoomProvider] submitRating error: $e');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final audioRoomProvider =
    StateNotifierProvider<AudioRoomNotifier, AudioRoomState>((ref) {
  return AudioRoomNotifier(ref);
});
