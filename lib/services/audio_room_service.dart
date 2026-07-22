import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';

/// Audio Room API Service for WiTalk Adda feature.
/// Ports logic from React Native's src/api/audioRoom.js
class AudioRoomService {
  static final AudioRoomService _instance = AudioRoomService._internal();
  factory AudioRoomService() => _instance;
  AudioRoomService._internal();

  static const String baseUrl = '/v1/audio-rooms';

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

  /// Get upcoming scheduled audio rooms
  Future<Map<String, dynamic>> getUpcomingRooms({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final res = await dioClient.get(
        '$baseUrl/upcoming',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
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
}

final audioRoomService = AudioRoomService();
