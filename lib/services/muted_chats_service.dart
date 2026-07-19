import '../api/dio_client.dart';

// Mirrors the RN mutedChats.js API
class MutedChatsService {
  static const _base = '/v1/muted-chats';

  Future<Map<String, dynamic>> muteChat({
    required String userId,
    required String mutedUserId,
    required String conversationId,
    required String muteDuration, // '8_hours' | '1_week' | 'always'
  }) async {
    final res = await dioClient.post('$_base/mute', data: {
      'userId': userId,
      'mutedUserId': mutedUserId,
      'conversationId': conversationId,
      'muteDuration': muteDuration,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unmuteChat({
    required String userId,
    required String mutedUserId,
  }) async {
    final res = await dioClient.post('$_base/unmute', data: {
      'userId': userId,
      'mutedUserId': mutedUserId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkMuteStatus({
    required String userId,
    required String mutedUserId,
  }) async {
    final res = await dioClient.get('$_base/check/$userId/$mutedUserId');
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getUserMutedChats(String userId) async {
    final res = await dioClient.get('$_base/user/$userId');
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    return [];
  }
}

final mutedChatsService = MutedChatsService();
