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

  // Sets notification preference: 'all' | 'smart' | 'mentions_replies' | 'muted'
  Future<void> setNotificationPreference(
      String userId, String groupId, String preference) async {
    if (preference == 'all') {
      await unmuteGroup(userId: userId, groupId: groupId);
    } else {
      await muteGroup(
        userId: userId,
        groupId: groupId,
        muteDuration: 'always',
        notificationType: preference,
      );
    }
  }

  // Returns { success, data: { isMuted, notificationPreference, ... } }
  Future<Map<String, dynamic>?> checkGroupMuteStatus(
      String userId, String groupId) async {
    try {
      final res = await dioClient.get('$_base/check/$userId/$groupId');
      return res.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
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
