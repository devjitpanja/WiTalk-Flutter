import '../api/dio_client.dart';

class MutedGroupsService {
  static const _base = '/v1/muted-groups';

  Future<Map<String, dynamic>> muteGroup({
    required String userId,
    required String groupId,
    String notificationType = 'muted',
    String muteDuration = 'always',
  }) async {
    final res = await dioClient.post('$_base/mute', data: {
      'userId': userId,
      'groupId': groupId,
      'notificationType': notificationType,
      'muteDuration': muteDuration,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unmuteGroup({
    required String userId,
    required String groupId,
  }) async {
    final res = await dioClient.post('$_base/unmute', data: {
      'userId': userId,
      'groupId': groupId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getUserMutedGroups(String userId) async {
    final res = await dioClient.get('$_base/user/$userId');
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    return [];
  }
}

final mutedGroupsService = MutedGroupsService();
