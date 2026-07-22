import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_room_service.dart';

/// ParticipantManager — manages the participant profile cache for a Live Audio Room.
///
/// Port of the RN useParticipants.js hook. Keeps a flat map of:
///   uid → { uid, name, avatar, role, isHost, isAdmin, isMuted,
///            isVerified, verificationBadge, avatarFrameUrl, soundLevel }
///
/// The cache is populated from:
///   1. The join response `stage_layout` (seed)
///   2. The `seat_state` socket event's `participants` array (seed)
///   3. `participant_joined` / `participant_left` socket events (incremental)
///   4. `fetchRoomParticipants()` — periodic background poll + on-demand
///   5. `fetchMissingSeatedProfiles()` — triggered when seated UIDs have no profile
class ParticipantManager {
  // ── Profile cache ───────────────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _profiles = {};

  /// Read-only view of the current profile cache.
  Map<String, Map<String, dynamic>> get profiles =>
      Map.unmodifiable(_profiles);

  // ── Event stream ───────────────────────────────────────────────────────────
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  // ── Services ────────────────────────────────────────────────────────────────
  final _audioRoomService = audioRoomService;

  // ── Internal state ──────────────────────────────────────────────────────────
  String? _roomId;
  Timer? _pollTimer;
  Timer? _joinDebounce;

  static const _pollIntervalMs = 120000; // 2-minute safety-net poll

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void initialize(String roomId) {
    _roomId = roomId;
    _fetchRoomParticipants();
    _startPolling();
  }

  void dispose() {
    _pollTimer?.cancel();
    _joinDebounce?.cancel();
    _eventController.close();
    _profiles.clear();
  }

  void reset() {
    _pollTimer?.cancel();
    _joinDebounce?.cancel();
    _profiles.clear();
  }

  // ── Seeding ─────────────────────────────────────────────────────────────────

  /// Seeds initial profiles from the join response stage_layout.
  void seedFromStageLayout(List<Map<String, dynamic>> stageLayout,
      {String? hostUid}) {
    for (final entry in stageLayout) {
      final uid = entry['uid']?.toString();
      if (uid == null) continue;
      _mergeProfile(uid, {
        'uid': uid,
        'name': entry['name']?.toString() ??
            entry['display_name']?.toString() ??
            'User',
        'avatar': entry['profile_pic']?.toString() ??
            entry['avatar']?.toString(),
        'isHost': entry['isHost'] == true || uid == hostUid,
        'isAdmin':
            entry['role'] == 'admin' || entry['role'] == 'host',
        'isMuted': true,
        'soundLevel': 0.0,
      });
    }
    _emitUpdated();
  }

  /// Seeds admin/role info from the join response `admins` list.
  void seedParticipantRoles(List<dynamic> admins) {
    for (final a in admins) {
      final uid = a['uid']?.toString() ?? a.toString();
      if (uid.isEmpty) continue;
      _mergeProfile(uid, {'isAdmin': true, 'role': 'admin'});
    }
    _emitUpdated();
  }

  // ── Participant events ──────────────────────────────────────────────────────

  void onParticipantJoined(Map<String, dynamic> data) {
    final uid = data['uid']?.toString() ?? data['userId']?.toString();
    if (uid == null || uid.isEmpty) return;
    _mergeProfile(uid, {
      'uid': uid,
      'name': data['name']?.toString() ??
          data['userName']?.toString() ??
          'User',
      'avatar': data['profile_pic']?.toString() ??
          data['avatar']?.toString(),
      'isHost': data['isHost'] == true,
      'isAdmin': data['role'] == 'admin' || data['isAdmin'] == true,
      'isMuted': true,
      'soundLevel': 0.0,
    });
    _emitUpdated();

    // Debounce-fetch to coalesce multiple rapid joins
    _joinDebounce?.cancel();
    _joinDebounce =
        Timer(const Duration(milliseconds: 500), _fetchRoomParticipants);
  }

  void onParticipantLeft(String uid) {
    _profiles.remove(uid);
    _emitUpdated();
  }

  /// Called when mic state changes via socket `mic_state` or LiveKit track events.
  void updateParticipantMic(String uid, bool isMicOn) {
    if (!_profiles.containsKey(uid)) return;
    _profiles[uid] = {..._profiles[uid]!, 'isMuted': !isMicOn};
    _emitUpdated();
  }

  /// Called from LiveKit sound-level events.
  void updateSoundLevel(String uid, double level) {
    if (!_profiles.containsKey(uid)) return;
    _profiles[uid] = {..._profiles[uid]!, 'soundLevel': level};
    // Don't emit a full update for sound levels — they update too frequently.
    // The UI reads soundLevels from audioRoomProvider.soundLevels directly.
  }

  /// Called when a `role_updated` socket event is received.
  void onRoleUpdated(String uid, String newRole) {
    _mergeProfile(uid, {
      'role': newRole,
      'isAdmin': newRole == 'admin' || newRole == 'host',
      'isHost': newRole == 'host',
    });
    _emitUpdated();
  }

  // ── Profile getters ─────────────────────────────────────────────────────────

  Map<String, dynamic>? getProfile(String uid) => _profiles[uid];

  String getDisplayName(String uid) {
    return _profiles[uid]?['name']?.toString() ?? 'User';
  }

  String? getAvatar(String uid) {
    return _profiles[uid]?['avatar']?.toString();
  }

  bool isAdmin(String uid) {
    return _profiles[uid]?['isAdmin'] == true;
  }

  bool isMuted(String uid) {
    return _profiles[uid]?['isMuted'] != false;
  }

  // ── Missing profile fetch ───────────────────────────────────────────────────

  /// Fetches profiles for UIDs that are in seats but not in the cache.
  /// Triggered from provider when a seat_state event reveals unknown UIDs.
  Future<void> fetchMissingSeatedProfiles(List<String> seatedUids) async {
    final missing = seatedUids
        .where((uid) =>
            !_profiles.containsKey(uid) ||
            _profiles[uid]?['name'] == null ||
            _profiles[uid]?['name'] == 'User' ||
            _profiles[uid]?['name'] == uid)
        .toList();

    if (missing.isEmpty) return;

    try {
      final results =
          await _audioRoomService.fetchUsersByIds(missing);
      for (final user in results) {
        final uid = user['uid']?.toString() ?? user['id']?.toString();
        if (uid == null) continue;
        _mergeProfile(uid, {
          'uid': uid,
          'name': user['name']?.toString() ?? 'User',
          'avatar': user['profile_pic']?.toString() ??
              user['profile_pic_medium']?.toString(),
          'isVerified': user['is_verified'] == true,
          'verificationBadge': user['verification_badge'],
          'avatarFrameUrl': user['avatar_frame_url'],
        });
      }
      _emitUpdated();
    } catch (e) {
      if (kDebugMode) {
        print('[ParticipantManager] fetchMissingSeatedProfiles error: $e');
      }
    }
  }

  // ── Periodic poll ───────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _pollIntervalMs),
      (_) => _fetchRoomParticipants(),
    );
  }

  Future<void> _fetchRoomParticipants() async {
    if (_roomId == null) return;
    try {
      final res =
          await _audioRoomService.fetchRoomParticipants(_roomId!);
      if (res['success'] == true && res['data'] is List) {
        for (final p in (res['data'] as List)) {
          if (p is! Map<String, dynamic>) continue;
          final uid = p['uid']?.toString();
          if (uid == null) continue;
          _mergeProfile(uid, {
            'uid': uid,
            'name': p['name']?.toString() ?? 'User',
            'avatar': p['profile_pic_medium']?.toString() ??
                p['profile_pic']?.toString(),
            'isHost': p['role'] == 'host',
            'isAdmin': p['role'] == 'admin' || p['role'] == 'host',
            'isVerified': p['is_verified'] == true,
            'verificationBadge': p['verification_badge'],
            'avatarFrameUrl': p['avatar_frame_url'],
          });
        }
        _emitUpdated();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ParticipantManager] _fetchRoomParticipants error: $e');
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _mergeProfile(String uid, Map<String, dynamic> updates) {
    final avatarUrl = updates['avatar'] ?? updates['profile_pic'] ?? updates['profile_pic_medium'];
    final name = updates['name'] ?? updates['userName'] ?? updates['display_name'];

    _profiles[uid] = {
      ...(_profiles[uid] ?? {'uid': uid, 'isMuted': true, 'soundLevel': 0.0}),
      ...updates,
      if (avatarUrl != null) 'avatar': avatarUrl,
      if (avatarUrl != null) 'profile_pic': avatarUrl,
      if (name != null) 'name': name,
    };
  }

  void _emitUpdated() {
    if (!_eventController.isClosed) {
      _eventController.add({'event': 'profiles_updated'});
    }
  }
}
