import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/dio_client.dart';

/// Audio Room API Service for WiTalk Adda feature.
/// Ports logic from React Native's src/api/audioRoom.js and
/// inline calls in LiveAudioRoomScreen.jsx.
class AudioRoomService {
  static final AudioRoomService _instance = AudioRoomService._internal();
  factory AudioRoomService() => _instance;
  AudioRoomService._internal();

  static const String baseUrl = '/v1/audio-rooms';

  // ── Room listing ────────────────────────────────────────────────────────────

  /// Get active audio rooms
  Future<Map<String, dynamic>> getActiveRooms({
    int limit = 50,
    int offset = 0,
    bool includePrivate = false,
  }) async {
    try {
      final res = await dioClient.get(
        baseUrl,
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (includePrivate) 'include_private': 1,
        },
      );
      return res.data as Map<String, dynamic>? ?? {'success': true, 'data': []};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error fetching active rooms: $e');
      return {'success': false, 'data': []};
    }
  }

  /// Get active audio rooms for a specific group
  Future<Map<String, dynamic>> getGroupActiveRooms(String groupId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await dioClient.get(
        '$baseUrl/group/$groupId',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true, 'data': []};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error fetching group active rooms: $e');
      return {'success': false, 'data': []};
    }
  }

  /// Get upcoming scheduled audio rooms
  Future<Map<String, dynamic>> getUpcomingRooms({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final res = await dioClient.get(
        '$baseUrl/upcoming',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true, 'data': []};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error fetching upcoming rooms: $e');
      return {'success': false, 'data': []};
    }
  }

  /// Get Adda feature settings (public)
  Future<Map<String, dynamic>> getAddaSettings() async {
    try {
      final res = await dioClient.get('$baseUrl/settings');
      return res.data as Map<String, dynamic>? ??
          {
            'success': true,
            'data': {
              'adda_server_enabled': true,
              'adda_creation_enabled': true,
              'adda_server_banner': '',
            }
          };
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error fetching settings: $e');
      return {
        'success': true,
        'data': {
          'adda_server_enabled': true,
          'adda_creation_enabled': true,
          'adda_server_banner': '',
        }
      };
    }
  }

  /// Toggle follow/unfollow for a scheduled adda
  Future<Map<String, dynamic>> toggleFollowSchedule(String roomId) async {
    try {
      final res = await dioClient.post('$baseUrl/$roomId/follow');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error toggling follow schedule: $e');
      rethrow;
    }
  }

  /// Delete a scheduled room
  Future<Map<String, dynamic>> deleteScheduledRoom(String roomId) async {
    try {
      final res = await dioClient.delete('$baseUrl/scheduled/$roomId');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error deleting scheduled room: $e');
      return {'success': false};
    }
  }

  /// Start a scheduled room now
  Future<Map<String, dynamic>> startScheduledRoom(String roomId) async {
    try {
      final res = await dioClient.post('$baseUrl/scheduled/$roomId/start');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error starting scheduled room: $e');
      return {'success': false};
    }
  }

  /// Get room details by room ID
  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    try {
      final res = await dioClient.get('$baseUrl/$roomId');
      return res.data as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] Error fetching room by ID: $e');
      return null;
    }
  }

  // ── Room join / leave lifecycle ─────────────────────────────────────────────

  /// Join a room — core call that returns livekit_token, stage_layout, user_data, etc.
  /// Mirrors RN's audioRoomAPI.joinRoom(roomId, role, frontendIp).
  Future<Map<String, dynamic>> joinRoom(
    String roomId,
    String role, {
    bool reconnect = false,
    String? joinIdentifier,
  }) async {
    String appVersion = '1';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion =
          info.buildNumber.isNotEmpty ? info.buildNumber : info.version;
    } catch (_) {}

    final effectiveRoomId = joinIdentifier ?? roomId;
    final res = await dioClient.post(
      '$baseUrl/$effectiveRoomId/join?app_version=$appVersion',
      data: {'role': role, 'reconnect': reconnect},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Leave a room — notifies backend, clears participant record.
  Future<Map<String, dynamic>> leaveRoom(String roomId) async {
    try {
      final res = await dioClient.post('$baseUrl/$roomId/leave');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] leaveRoom error: $e');
      return {'success': false};
    }
  }

  /// End a room (host only) — sets active=false in DB.
  Future<Map<String, dynamic>> endRoom(String roomId) async {
    try {
      final res = await dioClient.post('$baseUrl/$roomId/end');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] endRoom error: $e');
      return {'success': false};
    }
  }

  /// Check room health — returns { active: bool, has_host: bool }.
  /// Used by the 90s health check timer and the 5-min host departure timer.
  Future<Map<String, dynamic>> checkRoomHealth(String roomId) async {
    final res = await dioClient.get('$baseUrl/$roomId/health');
    return res.data as Map<String, dynamic>;
  }

  // ── Participants ────────────────────────────────────────────────────────────

  /// Fetch all active participants for a room (from DB, with profile data).
  Future<Map<String, dynamic>> fetchRoomParticipants(String roomId) async {
    try {
      final res = await dioClient.get('$baseUrl/$roomId/participants');
      return res.data as Map<String, dynamic>? ?? {'success': true, 'data': []};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] fetchRoomParticipants error: $e');
      return {'success': false, 'data': []};
    }
  }

  /// Fetch profiles for a list of UIDs (fallback when participant is in seat
  /// but missing from participants table — uses /v1/users/batch or per-user).
  Future<List<Map<String, dynamic>>> fetchUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      final res = await dioClient.post(
        '/v1/users/batch',
        data: {'uids': uids},
      );
      final data = res.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      // Fallback: fetch each UID individually
      final results = <Map<String, dynamic>>[];
      for (final uid in uids) {
        try {
          final r = await dioClient.get('/v1/user/$uid');
          final d = r.data;
          if (d is Map && d['data'] != null) {
            results.add(Map<String, dynamic>.from(d['data'] as Map));
          }
        } catch (_) {}
      }
      return results;
    }
  }

  /// Get a single user's profile. Used for host profile on RoomEnded screen.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final res = await dioClient.get('/v1/user/$uid');
      final d = res.data;
      if (d is Map && d['data'] != null) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] getUserProfile error: $e');
      return null;
    }
  }

  /// Update a participant's seat index in the DB.
  Future<void> updateParticipantSeat(
      String roomId, String uid, int seatIndex) async {
    try {
      await dioClient.post(
        '$baseUrl/$roomId/participants/$uid/seat',
        data: {'seat_index': seatIndex},
      );
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] updateParticipantSeat error: $e');
    }
  }

  // ── Moderation ──────────────────────────────────────────────────────────────

  /// Ban a participant from the room.
  Future<Map<String, dynamic>> banParticipant(
      String roomId, String uid) async {
    try {
      final res = await dioClient.post(
        '$baseUrl/$roomId/ban',
        data: {'uid': uid},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] banParticipant error: $e');
      return {'success': false};
    }
  }

  /// Unban a previously banned user.
  Future<Map<String, dynamic>> unbanUser(String roomId, String uid) async {
    try {
      final res = await dioClient.post(
        '$baseUrl/$roomId/unban',
        data: {'uid': uid},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] unbanUser error: $e');
      return {'success': false};
    }
  }

  /// Get list of banned users for the room.
  Future<Map<String, dynamic>> getBannedUsers(String roomId) async {
    try {
      final res = await dioClient.get('$baseUrl/$roomId/banned');
      return res.data as Map<String, dynamic>? ?? {'success': true, 'data': []};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] getBannedUsers error: $e');
      return {'success': false, 'data': []};
    }
  }

  /// Promote a participant to admin role.
  Future<Map<String, dynamic>> promoteAdmin(String roomId, String uid) async {
    try {
      final res = await dioClient.post(
        '$baseUrl/$roomId/admins',
        data: {'uid': uid},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] promoteAdmin error: $e');
      return {'success': false};
    }
  }

  /// Remove admin role from a participant.
  Future<Map<String, dynamic>> removeAdminRole(
      String roomId, String uid) async {
    try {
      final res = await dioClient.delete('$baseUrl/$roomId/admins/$uid');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] removeAdminRole error: $e');
      return {'success': false};
    }
  }

  /// Kick a user from the room (no ban, just remove from room).
  Future<Map<String, dynamic>> kickUser(String roomId, String uid) async {
    try {
      final res = await dioClient.post(
        '$baseUrl/$roomId/kick',
        data: {'uid': uid},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] kickUser error: $e');
      return {'success': false};
    }
  }

  // ── Room settings ───────────────────────────────────────────────────────────

  /// Update room metadata (room_name, topic, etc.)
  Future<Map<String, dynamic>> updateRoom(
      String roomId, Map<String, dynamic> data) async {
    try {
      final res = await dioClient.patch('$baseUrl/$roomId', data: data);
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] updateRoom error: $e');
      return {'success': false};
    }
  }

  /// Update max seat count for the room.
  Future<Map<String, dynamic>> updateSeatCount(
      String roomId, int maxSeats) async {
    try {
      final res = await dioClient.patch(
        '$baseUrl/$roomId',
        data: {'max_seats': maxSeats},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] updateSeatCount error: $e');
      return {'success': false};
    }
  }

  /// Persist stage_request_enabled flag to DB.
  Future<Map<String, dynamic>> updateStageRequestEnabled(
      String roomId, bool enabled) async {
    try {
      final res = await dioClient.patch(
        '$baseUrl/$roomId',
        data: {'stage_request_enabled': enabled ? 1 : 0},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] updateStageRequestEnabled error: $e');
      return {'success': false};
    }
  }

  /// Toggle cool-down mode for community addas.
  Future<Map<String, dynamic>> toggleCoolDownMode(
      String roomId, bool enabled) async {
    try {
      final res = await dioClient.post(
        '$baseUrl/$roomId/cool-down',
        data: {'enabled': enabled},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] toggleCoolDownMode error: $e');
      return {'success': false};
    }
  }

  // ── Recording ───────────────────────────────────────────────────────────────

  /// Trigger backend to start LiveKit egress recording.
  Future<Map<String, dynamic>> startRecording(String roomId) async {
    try {
      final res =
          await dioClient.post('$baseUrl/$roomId/start-recording');
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] startRecording error: $e');
      return {'success': false};
    }
  }

  // ── Community roles ─────────────────────────────────────────────────────────

  /// Get community roles map for participants (uid → role string).
  Future<Map<String, dynamic>> getCommunityRoles(String roomId) async {
    try {
      final res = await dioClient.get('$baseUrl/$roomId/community-roles');
      return res.data as Map<String, dynamic>? ?? {'success': true, 'roles': {}};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] getCommunityRoles error: $e');
      return {'success': false, 'roles': {}};
    }
  }

  // ── Ratings ─────────────────────────────────────────────────────────────────

  /// Get room rating status for the current user.
  Future<Map<String, dynamic>> getRoomRatingStatus(String roomId) async {
    try {
      final res = await dioClient.get('$baseUrl/$roomId/rating');
      return res.data as Map<String, dynamic>? ?? {'success': true, 'has_rated': false};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] getRoomRatingStatus error: $e');
      return {'success': false, 'has_rated': false};
    }
  }

  /// Submit a room rating and optional review.
  Future<Map<String, dynamic>> submitRating(
      String roomId, int rating, {String? review}) async {
    try {
      final res = await dioClient.post(
        '$baseUrl/$roomId/rating',
        data: {'rating': rating, if (review != null) 'review': review},
      );
      return res.data as Map<String, dynamic>? ?? {'success': true};
    } catch (e) {
      if (kDebugMode) print('[AudioRoomService] submitRating error: $e');
      return {'success': false};
    }
  }
}

final audioRoomService = AudioRoomService();
