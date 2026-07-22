import 'dart:async';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/dio_client.dart';
import '../services/livekit_audio_manager.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';

// Helper to get cached user name from shared prefs if available
String _resolveUserName(AuthState authState) {
  return authState.uid ?? 'User';
}

// ── State ─────────────────────────────────────────────────────────────────────

class AudioRoomState {
  final String? roomId;
  final String roomName;
  final String? topic;
  final String? hostUid;
  final String? hostName;
  final String? hostProfilePic;
  final String? language;
  final int maxSeats;
  final bool isPublic;
  final bool isHost;
  final bool isCoHost;
  final bool isSpeaker;
  final bool isMuted;
  final bool isHandRaised;
  final int currentSeatIndex;
  final bool isMinimised;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  final List<Map<String, dynamic>> speakers;
  final List<Map<String, dynamic>> audience;
  final List<Map<String, dynamic>> handRaiseQueue;
  final List<Map<String, dynamic>> chatMessages;

  final String? activeSpeakerUid;
  final String audioOutputMode; // 'speaker' | 'earpiece' | 'bluetooth'

  // YouTube / Media sync state
  final String? youtubeVideoId;
  final bool youtubeIsPlaying;
  final double youtubeCurrentTime;

  // Additional Room Config & Admin State
  final List<String> admins;
  final List<String> bannedUsers;
  final Map<String, dynamic> communityRolesMap;
  final bool coolDownMode;
  final String? roomInviteToken;
  final bool isRoomPublic;
  final bool stageRequestEnabled;
  final int dailyLimitMinutes;
  final double? roomAverageRating;
  final bool isInSeat;

  /// Microphone sound levels — userId → 0.0..1.0
  final Map<String, double> soundLevels;

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
    this.isSpeaker = false,
    this.isMuted = true,
    this.isHandRaised = false,
    this.currentSeatIndex = -1,
    this.isMinimised = false,
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.speakers = const [],
    this.audience = const [],
    this.handRaiseQueue = const [],
    this.chatMessages = const [],
    this.activeSpeakerUid,
    this.audioOutputMode = 'speaker',
    this.youtubeVideoId,
    this.youtubeIsPlaying = false,
    this.youtubeCurrentTime = 0.0,
    this.admins = const [],
    this.bannedUsers = const [],
    this.communityRolesMap = const {},
    this.coolDownMode = false,
    this.roomInviteToken,
    this.isRoomPublic = true,
    this.stageRequestEnabled = true,
    this.dailyLimitMinutes = 0,
    this.roomAverageRating,
    this.isInSeat = false,
    this.soundLevels = const {},
  });

  AudioRoomState copyWith({
    String? roomId,
    String? roomName,
    String? topic,
    String? hostUid,
    String? hostName,
    String? hostProfilePic,
    String? language,
    int? maxSeats,
    bool? isPublic,
    bool? isHost,
    bool? isCoHost,
    bool? isSpeaker,
    bool? isMuted,
    bool? isHandRaised,
    int? currentSeatIndex,
    bool? isMinimised,
    bool? isConnected,
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? speakers,
    List<Map<String, dynamic>>? audience,
    List<Map<String, dynamic>>? handRaiseQueue,
    List<Map<String, dynamic>>? chatMessages,
    String? activeSpeakerUid,
    String? audioOutputMode,
    String? youtubeVideoId,
    bool? youtubeIsPlaying,
    double? youtubeCurrentTime,
    List<String>? admins,
    List<String>? bannedUsers,
    Map<String, dynamic>? communityRolesMap,
    bool? coolDownMode,
    String? roomInviteToken,
    bool? isRoomPublic,
    bool? stageRequestEnabled,
    int? dailyLimitMinutes,
    double? roomAverageRating,
    bool? isInSeat,
    Map<String, double>? soundLevels,
  }) {
    return AudioRoomState(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      topic: topic ?? this.topic,
      hostUid: hostUid ?? this.hostUid,
      hostName: hostName ?? this.hostName,
      hostProfilePic: hostProfilePic ?? this.hostProfilePic,
      language: language ?? this.language,
      maxSeats: maxSeats ?? this.maxSeats,
      isPublic: isPublic ?? this.isPublic,
      isHost: isHost ?? this.isHost,
      isCoHost: isCoHost ?? this.isCoHost,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isMuted: isMuted ?? this.isMuted,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      currentSeatIndex: currentSeatIndex ?? this.currentSeatIndex,
      isMinimised: isMinimised ?? this.isMinimised,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      speakers: speakers ?? this.speakers,
      audience: audience ?? this.audience,
      handRaiseQueue: handRaiseQueue ?? this.handRaiseQueue,
      chatMessages: chatMessages ?? this.chatMessages,
      activeSpeakerUid: activeSpeakerUid ?? this.activeSpeakerUid,
      audioOutputMode: audioOutputMode ?? this.audioOutputMode,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      youtubeIsPlaying: youtubeIsPlaying ?? this.youtubeIsPlaying,
      youtubeCurrentTime: youtubeCurrentTime ?? this.youtubeCurrentTime,
      admins: admins ?? this.admins,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      communityRolesMap: communityRolesMap ?? this.communityRolesMap,
      coolDownMode: coolDownMode ?? this.coolDownMode,
      roomInviteToken: roomInviteToken ?? this.roomInviteToken,
      isRoomPublic: isRoomPublic ?? this.isRoomPublic,
      stageRequestEnabled: stageRequestEnabled ?? this.stageRequestEnabled,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      roomAverageRating: roomAverageRating ?? this.roomAverageRating,
      isInSeat: isInSeat ?? this.isInSeat,
      soundLevels: soundLevels ?? this.soundLevels,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AudioRoomNotifier extends StateNotifier<AudioRoomState> {
  final Ref ref;

  // Subscriptions to clean up on leave
  final List<StreamSubscription> _liveKitSubs = [];

  // Map of uid → participant info from LiveKit/socket
  final Map<String, Map<String, dynamic>> _participantCache = {};

  // Seat layout: index → uid  (the server-authoritative seat state)
  List<String?> _seats = [];

  AudioRoomNotifier(this.ref) : super(const AudioRoomState());

  // ── joinRoom ───────────────────────────────────────────────────────────────
  /// Joins a room:
  /// 1. Calls POST /v1/audio-rooms/{roomId}/join → gets livekit_token, livekit_url, stage_layout, etc.
  /// 2. Connects to the LiveKit server with the token.
  /// 3. Connects to Socket.IO and listens for real-time events.
  /// 4. If host → starts publishing audio immediately.
  Future<bool> joinRoom(
    String roomId, {
    bool isHost = false,
    String role = 'audience',
  }) async {
    state = state.copyWith(isLoading: true, roomId: roomId, isHost: isHost);

    try {
      final currentUid = ref.read(authProvider).uid ?? '';
      final authState = ref.read(authProvider);

      // ── Step 1: Call backend join API ──────────────────────────────────────
      final effectiveRole = isHost ? 'host' : role;

      // Backend requires ?app_version= query param — returns 426 without it
      String appVersion = '1';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.buildNumber.isNotEmpty ? info.buildNumber : '1';
      } catch (_) {}

      final response = await dioClient.post(
        '/v1/audio-rooms/$roomId/join?app_version=$appVersion',
        data: {'role': effectiveRole, 'reconnect': false},
      );

      final joinData = response.data as Map<String, dynamic>;

      if (joinData['success'] != true) {
        final msg = joinData['message'] ?? 'Failed to join room';
        state = state.copyWith(isLoading: false, error: msg.toString());
        return false;
      }

      // ── Step 2: Extract room metadata ──────────────────────────────────────
      final data = (joinData['data'] ?? {}) as Map<String, dynamic>;
      final livekitToken = joinData['livekit_token']?.toString() ?? '';
      final livekitUrl = joinData['livekit_url']?.toString() ?? '';
      final iceServers = joinData['ice_servers'] as List<dynamic>?;

      final hostUid = data['host_uid']?.toString();
      final actualIsHost =
          isHost || (hostUid != null && hostUid == currentUid);
      final myRole = joinData['my_role']?.toString() ?? effectiveRole;
      final actualIsAdmin =
          myRole == 'admin' || myRole == 'host' || actualIsHost;

      final admins = (data['admins'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final maxSeats = (data['max_seats'] as int?) ?? 8;
      final stageRequestEnabled =
          data['stage_request_enabled'] != null
              ? data['stage_request_enabled'] == 1 ||
                  data['stage_request_enabled'] == true
              : true;

      // Seed initial speakers list from stage_layout in join response
      final stageLayout =
          (joinData['stage_layout'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      _seats = List.filled(maxSeats, null);
      for (final entry in stageLayout) {
        final uid = entry['uid']?.toString();
        final seatIndex = entry['seat_index'];
        final si = seatIndex is int
            ? seatIndex
            : int.tryParse(seatIndex?.toString() ?? '') ?? -1;
        if (uid != null && si >= 0 && si < maxSeats) {
          _seats[si] = uid;
        }
        // Seed participant cache with name/avatar from stage_layout
        if (uid != null) {
          _participantCache[uid] = {
            'uid': uid,
            'name': entry['name']?.toString() ??
                entry['display_name']?.toString() ??
                'User',
            'profile_pic': entry['profile_pic']?.toString() ??
                entry['avatar']?.toString(),
            'isHost': entry['isHost'] == true || uid == hostUid,
          };
        }
      }
      final initialSpeakers = _buildSpeakersList(hostUid, currentUid);

      // Seed self in participant cache
      _participantCache[currentUid] = {
        'uid': currentUid,
        'name': currentUid,
        'profile_pic': null,
        'isHost': actualIsHost,
        'isAdmin': actualIsAdmin,
        'isMuted': !actualIsHost,
      };

      state = state.copyWith(
        roomId: roomId,
        roomName: data['room_name']?.toString() ?? 'WiTalk Adda',
        topic: data['topic']?.toString(),
        hostUid: hostUid,
        hostName: data['host_name']?.toString() ?? data['host_username']?.toString(),
        hostProfilePic: data['host_profile_pic']?.toString(),
        language: data['language']?.toString(),
        maxSeats: maxSeats,
        isPublic: data['is_public'] == true || data['is_public'] == 1,
        isHost: actualIsHost,
        isSpeaker: actualIsHost,
        isMuted: !actualIsHost, // host starts unmuted
        currentSeatIndex: actualIsHost ? 0 : -1,
        isConnected: true,
        isLoading: false,
        isMinimised: false,
        admins: admins,
        stageRequestEnabled: stageRequestEnabled,
        coolDownMode: data['cool_down_mode'] == true ||
            data['cool_down_mode'] == 1,
        isRoomPublic: data['is_public'] != 0 && data['is_public'] != false,
        roomInviteToken: data['invite_token']?.toString(),
        roomAverageRating: data['average_rating'] != null
            ? double.tryParse(data['average_rating'].toString())
            : null,
        speakers: initialSpeakers,
        audience: [],
      );

      // ── Step 3: Connect LiveKit ────────────────────────────────────────────
      if (livekitToken.isNotEmpty && livekitUrl.isNotEmpty) {
        liveKitAudioManager.prepareConnection(livekitUrl);

        await liveKitAudioManager.joinRoom(
          roomId: roomId,
          userId: currentUid,
          userName: currentUid,
          token: livekitToken,
          livekitUrl: livekitUrl,
          iceServers: iceServers
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );

        // ── Step 4: Subscribe to LiveKit events ───────────────────────────────
        _listenToLiveKitEvents(currentUid, roomId);

        // If host → start publishing audio immediately
        if (actualIsHost) {
          try {
            await liveKitAudioManager.setMicrophoneEnabled(true);
          } catch (e) {
            if (kDebugMode) {
              print('[AudioRoomProvider] Host mic start failed: $e');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print(
              '[AudioRoomProvider] WARNING: No LiveKit credentials in join response. Audio disabled.');
        }
      }

      // ── Step 5: Connect Socket.IO and listen for real-time updates ─────────
      await socketService.connect();
      socketService.emitAudioRoom('join_room', {'roomId': roomId});
      // Request authoritative seat state right away
      socketService.emitAudioRoom('seat_state_request', {'roomId': roomId});
      _setupSocketListeners(roomId, currentUid, hostUid);

      return true;
    } catch (e) {
      if (kDebugMode) print('[AudioRoomProvider] joinRoom error: $e');
      // Parse a clean message from Dio errors
      String msg = 'Unable to join this room. Please try again.';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final serverMsg = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString()
            : null;
        if (statusCode == 426) {
          msg = 'Please update the app to join this room.';
        } else if (statusCode == 403) {
          msg = 'You are not allowed to join this room.';
        } else if (statusCode == 404) {
          msg = 'This room no longer exists.';
        } else if (serverMsg != null && serverMsg.isNotEmpty) {
          msg = serverMsg;
        }
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  // ── LiveKit Event Listeners ────────────────────────────────────────────────
  void _listenToLiveKitEvents(String myUid, String roomId) {
    final sub = liveKitAudioManager.eventStream.listen((event) {
      final eventType = event['event'] as String?;
      if (eventType == null) return;

      switch (eventType) {
        case LiveKitAudioEvents.roomUserUpdate:
          final updateType = event['updateType'] as String?;
          final userList =
              (event['userList'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (updateType == RoomUpdateType.add) {
            for (final user in userList) {
              final uid = user['userID']?.toString() ?? '';
              if (uid.isEmpty) continue;
              _participantCache[uid] = {
                ...(_participantCache[uid] ?? {}),
                'uid': uid,
                'name': user['userName']?.toString() ?? uid,
              };
            }
          } else if (updateType == RoomUpdateType.delete) {
            for (final user in userList) {
              final uid = user['userID']?.toString() ?? '';
              // Remove from audience list if they leave
              final updatedAudience = state.audience
                  .where((p) => p['uid'] != uid)
                  .toList();
              state = state.copyWith(audience: updatedAudience);
            }
          }
          break;

        case LiveKitAudioEvents.streamUpdate:
          // Update mute state in speakers list
          final uid = event['userID']?.toString();
          final isMicOn = event['isMicOn'] as bool?;
          if (uid != null && isMicOn != null) {
            final updatedSpeakers = state.speakers.map((s) {
              if (s['uid'] == uid) {
                return {...s, 'isMuted': !isMicOn};
              }
              return s;
            }).toList();
            state = state.copyWith(speakers: updatedSpeakers);
          }
          break;

        case LiveKitAudioEvents.roomStateChanged:
          final errorCode = event['errorCode'] as int?;
          if (errorCode == 1002034) {
            // Room ended by host
            state = state.copyWith(error: 'This room has ended.');
            leaveRoom();
          } else if (errorCode == 1002035) {
            // Kicked by admin
            state = state.copyWith(error: 'You were removed from this room.');
            leaveRoom();
          }
          break;

        case LiveKitAudioEvents.microphoneStateChanged:
          final enabled = event['enabled'] as bool? ?? false;
          state = state.copyWith(isMuted: !enabled);
          break;
      }
    });
    _liveKitSubs.add(sub);
  }

  // ── Socket Event Listeners ─────────────────────────────────────────────────
  void _setupSocketListeners(
      String roomId, String myUid, String? hostUid) {
    socketService.onAudioRoom('message_history', (data) {
      if (data is List) {
        final messages = data.cast<Map<String, dynamic>>();
        state = state.copyWith(chatMessages: messages);
      }
    });

    socketService.onAudioRoom('new_message', (data) {
      if (data is Map<String, dynamic>) {
        final updated = List<Map<String, dynamic>>.from(state.chatMessages)
          ..add(data);
        state = state.copyWith(chatMessages: updated);
      }
    });

    // ── Authoritative seat state from server ─────────────────────────────────
    // This is the core event that drives who is on stage.
    socketService.onAudioRoom('seat_state', (data) {
      if (kDebugMode) {
        print('[AudioRoomProvider] seat_state received: $data');
      }
      if (data is! Map<String, dynamic>) return;
      _applySeatState(data, myUid, hostUid);
    });

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
            final updated = List<Map<String, dynamic>>.from(state.handRaiseQueue)
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

    socketService.onAudioRoom('participant_joined', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString() ?? '';
        if (uid.isEmpty) return;
        _participantCache[uid] = {
          ...(_participantCache[uid] ?? {}),
          ...data,
        };
        // Add to audience if not already in speakers
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
        _participantCache.remove(uid);
        // Remove from both speakers (by clearing that seat) and audience
        for (int i = 0; i < _seats.length; i++) {
          if (_seats[i] == uid) _seats[i] = null;
        }
        final updatedAudience =
            state.audience.where((a) => a['uid'] != uid).toList();
        state = state.copyWith(
          speakers: _buildSpeakersList(state.hostUid, myUid),
          audience: updatedAudience,
        );
      }
    });

    socketService.onAudioRoom('mic_state', (data) {
      if (data is Map<String, dynamic>) {
        final uid = data['uid']?.toString();
        final isMicOn = data['isMicOn'] == true;
        if (uid == null) return;
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

    socketService.onAudioRoom('room_ended', (data) {
      state = state.copyWith(error: 'This room has been ended by the host.');
      leaveRoom();
    });

    socketService.onAudioRoom('user_banned', (data) {
      state = state.copyWith(error: 'You have been banned from this room.');
      leaveRoom();
    });

    socketService.onAudioRoom('reaction_received', (data) {
      // Reactions handled by UI layer directly via event stream if needed
    });
  }

  // ── _applySeatState ────────────────────────────────────────────────────────
  /// Processes a `seat_state` socket event and rebuilds the speakers/audience lists.
  /// seat_state payload format (from backend):
  /// { seats: [uid|null, ...], lockedSeats: [int,...], stageRequestEnabled: bool,
  ///   maxSeats: int, participants: [{uid, name, profile_pic, ...}] }
  void _applySeatState(
      Map<String, dynamic> payload, String myUid, String? hostUid) {
    final seats = payload['seats'] as List?;
    if (seats == null) return;

    final maxSeats = (payload['maxSeats'] as int?) ??
        (payload['max_seats'] as int?) ??
        state.maxSeats;

    // Update seat layout
    _seats = List.filled(maxSeats, null);
    for (int i = 0; i < seats.length && i < maxSeats; i++) {
      _seats[i] = seats[i]?.toString();
    }

    // Seed participant cache from payload's participants list if provided
    final participants = payload['participants'] as List?;
    if (participants != null) {
      for (final p in participants) {
        if (p is! Map<String, dynamic>) continue;
        final uid = p['uid']?.toString() ?? p['user_id']?.toString();
        if (uid == null) continue;
        _participantCache[uid] = {...(_participantCache[uid] ?? {}), ...p};
      }
    }

    // stageRequestEnabled
    final sre = payload['stageRequestEnabled'] ??
        payload['stage_request_enabled'];
    final stageRequestEnabled = sre == null
        ? state.stageRequestEnabled
        : (sre == true || sre == 1);

    // Determine if I am now in a seat
    final mySeat = _seats.indexOf(myUid);
    final wasInSeat = state.isInSeat;
    final nowInSeat = mySeat >= 0;

    // If we were just placed in a seat → start publishing audio
    if (nowInSeat && !wasInSeat && !liveKitAudioManager.isPublishing) {
      _onSeatAssigned(mySeat, myUid);
    }

    // If we were removed from a seat → stop publishing
    if (!nowInSeat && wasInSeat && liveKitAudioManager.isPublishing) {
      liveKitAudioManager.stopPublishing().catchError((_) {});
    }

    final updatedSpeakers = _buildSpeakersList(hostUid, myUid);

    state = state.copyWith(
      speakers: updatedSpeakers,
      maxSeats: maxSeats,
      stageRequestEnabled: stageRequestEnabled,
      currentSeatIndex: mySeat,
      isInSeat: nowInSeat,
      isSpeaker: nowInSeat || state.isHost,
    );

    if (kDebugMode) {
      print(
          '[AudioRoomProvider] Seats updated: ${_seats} → speakers: ${updatedSpeakers.length}');
    }
  }

  // ── _buildSpeakersList ─────────────────────────────────────────────────────
  /// Converts the flat seat array into a list of speaker maps for the UI.
  List<Map<String, dynamic>> _buildSpeakersList(
      String? hostUid, String myUid) {
    return _seats.asMap().entries.map((entry) {
      final idx = entry.key;
      final uid = entry.value;
      if (uid == null) {
        return <String, dynamic>{'seatIndex': idx, 'isEmpty': true};
      }
      final cached = _participantCache[uid] ?? {};
      return <String, dynamic>{
        'seatIndex': idx,
        'isEmpty': false,
        'uid': uid,
        'name': cached['name']?.toString() ?? cached['display_name']?.toString() ?? 'User',
        'profile_pic': cached['profile_pic']?.toString() ?? cached['avatar']?.toString(),
        'isHost': uid == hostUid || cached['isHost'] == true,
        'isMuted': cached['isMuted'] as bool? ?? true,
        'isSelf': uid == myUid,
      };
    }).toList();
  }

  // ── _onSeatAssigned ────────────────────────────────────────────────────────
  /// Called when the server places us in a seat — wait for LiveKit, then publish.
  Future<void> _onSeatAssigned(int seatIndex, String myUid) async {
    if (kDebugMode) {
      print('[AudioRoomProvider] Assigned to seat $seatIndex — starting audio');
    }
    try {
      await liveKitAudioManager.waitForRoomConnection(timeoutMs: 8000);
      if (liveKitAudioManager.isPublishing ||
          liveKitAudioManager.isPublishingInProgress) return;
      liveKitAudioManager.setSeatIndex(seatIndex);
      await liveKitAudioManager.startPublishing();
      // Start muted per RN behaviour — user unmutes manually
      await liveKitAudioManager.setMicrophoneEnabled(false);
      state = state.copyWith(isMuted: true, isSpeaker: true, currentSeatIndex: seatIndex);
    } catch (e) {
      if (kDebugMode) {
        print('[AudioRoomProvider] _onSeatAssigned failed: $e');
      }
    }
  }

  // ── leaveRoom ──────────────────────────────────────────────────────────────
  Future<void> leaveRoom() async {
    final roomId = state.roomId;

    // Cancel LiveKit subscriptions
    for (final sub in _liveKitSubs) {
      sub.cancel();
    }
    _liveKitSubs.clear();

    // Leave socket room
    if (roomId != null) {
      socketService.emitAudioRoom('leave_room', {'roomId': roomId});
    }
    _removeSocketListeners();

    // Call backend leave API (fire and forget)
    if (roomId != null) {
      dioClient
          .post('/v1/audio-rooms/$roomId/leave')
          .catchError((_) {});
    }

    // Disconnect from LiveKit
    await liveKitAudioManager.leaveRoom();

    _participantCache.clear();
    _seats = [];
    state = const AudioRoomState();
  }

  void _removeSocketListeners() {
    socketService.offAudioRoom('message_history');
    socketService.offAudioRoom('new_message');
    socketService.offAudioRoom('seat_state');
    socketService.offAudioRoom('hand_raise_queue');
    socketService.offAudioRoom('hand_raise_update');
    socketService.offAudioRoom('participant_joined');
    socketService.offAudioRoom('participant_left');
    socketService.offAudioRoom('mic_state');
    socketService.offAudioRoom('room_ended');
    socketService.offAudioRoom('user_banned');
    socketService.offAudioRoom('reaction_received');
  }

  // ── toggleMic ─────────────────────────────────────────────────────────────
  void toggleMic() {
    if (!state.isSpeaker && !state.isHost) return;
    final nextMute = !state.isMuted;
    state = state.copyWith(isMuted: nextMute);
    liveKitAudioManager.setMicrophoneEnabled(!nextMute);
  }

  // ── toggleHandRaise ───────────────────────────────────────────────────────
  void toggleHandRaise() {
    final nextState = !state.isHandRaised;
    state = state.copyWith(isHandRaised: nextState);
    if (nextState) {
      socketService.emitAudioRoom('seat_request', {'roomId': state.roomId});
    } else {
      socketService.emitAudioRoom(
          'cancel_seat_request', {'roomId': state.roomId});
    }
  }

  /// Audience member directly takes an empty seat (no hand-raise needed when stageRequestEnabled=false)
  void takeSeat(int seatIndex) {
    socketService.emitAudioRoom(
        'take_seat', {'roomId': state.roomId, 'seatIndex': seatIndex});
  }

  /// Speaker voluntarily leaves their stage seat (go off-stage)
  Future<void> leaveSeat() async {
    socketService.emitAudioRoom('leave_seat', {'roomId': state.roomId});
    await liveKitAudioManager.stopPublishing().catchError((_) {});
    state = state.copyWith(
      isInSeat: false,
      isSpeaker: state.isHost,
      currentSeatIndex: -1,
      isHandRaised: false,
      isMuted: true,
    );
  }

  // ── Host/Admin controls ───────────────────────────────────────────────────
  void acceptSeatRequest(String uid) {
    socketService.emitAudioRoom(
        'accept_seat_request', {'roomId': state.roomId, 'uid': uid});
    // Remove from hand raise queue
    final updated =
        state.handRaiseQueue.where((r) => r['uid'] != uid).toList();
    state = state.copyWith(handRaiseQueue: updated);
  }

  void rejectSeatRequest(String uid) {
    socketService.emitAudioRoom(
        'reject_seat_request', {'roomId': state.roomId, 'uid': uid});
    final updated =
        state.handRaiseQueue.where((r) => r['uid'] != uid).toList();
    state = state.copyWith(handRaiseQueue: updated);
  }

  void kickParticipant(String uid) {
    socketService.emitAudioRoom(
        'kick_user', {'roomId': state.roomId, 'uid': uid});
  }

  void muteParticipant(String uid) {
    socketService.emitAudioRoom(
        'mute_user', {'roomId': state.roomId, 'uid': uid});
  }

  void offStageParticipant(String uid) {
    socketService.emitAudioRoom(
        'off_stage', {'roomId': state.roomId, 'uid': uid});
  }

  void endRoom() {
    socketService.emitAudioRoom('end_room', {'roomId': state.roomId});
    dioClient
        .post('/v1/audio-rooms/${state.roomId}/end')
        .catchError((_) {});
    leaveRoom();
  }

  // ── Chat & Reactions ──────────────────────────────────────────────────────
  void sendChatMessage(String text) {
    if (text.isEmpty) return;
    final localMsg = {
      'senderName': 'You',
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final updated =
        List<Map<String, dynamic>>.from(state.chatMessages)..add(localMsg);
    state = state.copyWith(chatMessages: updated);
    socketService.emitAudioRoom('send_message', {
      'roomId': state.roomId,
      'text': text,
    });
  }

  void sendReaction(String emoji) {
    socketService.emitAudioRoom('send_reaction', {
      'roomId': state.roomId,
      'emoji': emoji,
    });
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  void toggleMinimised() {
    state = state.copyWith(isMinimised: !state.isMinimised);
  }

  void setAudioOutputMode(String mode) {
    state = state.copyWith(audioOutputMode: mode);
    liveKitAudioManager.setSpeakerEnabled(mode == 'speaker');
  }

  void setYouTubeState(
      {String? videoId, bool? isPlaying, double? currentTime}) {
    state = state.copyWith(
      youtubeVideoId: videoId ?? state.youtubeVideoId,
      youtubeIsPlaying: isPlaying ?? state.youtubeIsPlaying,
      youtubeCurrentTime: currentTime ?? state.youtubeCurrentTime,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final audioRoomProvider =
    StateNotifierProvider<AudioRoomNotifier, AudioRoomState>((ref) {
  return AudioRoomNotifier(ref);
});
