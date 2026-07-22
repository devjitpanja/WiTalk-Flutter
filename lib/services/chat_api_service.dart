import '../api/dio_client.dart';
import '../api/app_endpoints.dart';

// REST API operations for chat (socket-independent: message editing,
// conversation management, contact lists, link preview, translation).
class ChatApiService {
  // ── Conversations ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final res = await dioClient.get(AppEndpoints.userConversations(userId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data['conversations'] is List) {
      return List<Map<String, dynamic>>.from(data['conversations'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final res = await dioClient.get(AppEndpoints.conversation(conversationId));
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> createConversation({
    required String userId,
    required String otherUserId,
  }) async {
    final res = await dioClient.post(AppEndpoints.createConversation, data: {
      'user1_id': userId,
      'user2_id': otherUserId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> acceptConversation(String conversationId, String userId) async {
    await dioClient.put(
      AppEndpoints.acceptConversation(conversationId),
      data: {'userId': userId},
    );
  }

  Future<void> deleteConversation(String conversationId,
      {String deleteType = 'for_me'}) async {
    await dioClient.delete(
      AppEndpoints.deleteConversation(conversationId),
      data: {'delete_type': deleteType},
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
    String? userId,
  }) async {
    final res = await dioClient.get(
      '/v1/chat/conversations/$conversationId/messages',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (userId != null) 'userId': userId,
      },
    );
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String userId,
    required String newContent,
  }) async {
    final res = await dioClient.put(
      AppEndpoints.updateChatMessage(messageId),
      data: {'user_id': userId, 'new_content': newContent},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Link preview ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getLinkPreview(String url) async {
    try {
      final res = await dioClient.get(
        AppEndpoints.chatLinkPreview,
        queryParameters: {'url': url},
      );
      if (res.data['success'] == true && res.data['data'] != null) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Translation ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> translateMessage({
    required String messageId,
    required String targetLanguage,
    required String text,
  }) async {
    try {
      final res = await dioClient.post(AppEndpoints.chatTranslate, data: {
        'message_id': messageId,
        'target_language': targetLanguage,
        'text': text,
      });
      return res.data as Map<String, dynamic>?;
    } catch (_) {}
    return null;
  }

  // ── Contacts ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getContacts() async {
    final res = await dioClient.get(AppEndpoints.chatContacts);
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  // ── Message requests ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMessageRequests() async {
    final res = await dioClient.get(AppEndpoints.chatRequests);
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  // ── Groups ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    final res = await dioClient.get(AppEndpoints.userGroups(userId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data['groups'] is List) {
      return List<Map<String, dynamic>>.from(data['groups'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getGroupDetail(String groupId, {String? userId}) async {
    final res = await dioClient.get(
      AppEndpoints.groupDetail(groupId),
      queryParameters: {if (userId != null) 'userId': userId},
    );
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final res = await dioClient.get(AppEndpoints.groupMembers(groupId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<Map<String, dynamic>?> sendGroupMessageRest(
    String groupId, {
    required String senderId,
    required String content,
    required String messageType,
    String? mediaUrl,
    Map<String, dynamic>? mediaData,
    Map<String, dynamic>? metadata,
    String? replyToId,
    Map<String, dynamic>? replyTo,
    String? tempId,
  }) async {
    final res = await dioClient.post(
      AppEndpoints.groupMessages(groupId),
      data: {
        'group_id': groupId,
        'sender_id': senderId,
        'content': content,
        'message_type': messageType,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (mediaData != null) 'media_data': mediaData,
        if (metadata != null) 'metadata': metadata,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyTo != null) 'reply_to': replyTo,
        if (tempId != null) 'temp_id': tempId,
      },
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<List<Map<String, dynamic>>> getGroupMessages(
    String groupId, {
    int limit = 50,
    int offset = 0,
    String? userId,
  }) async {
    final res = await dioClient.get(
      AppEndpoints.groupMessages(groupId),
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (userId != null) 'userId': userId,
      },
    );
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    String? imageUrl,
    bool isPublic = false,
  }) async {
    final res = await dioClient.post(AppEndpoints.createGroup, data: {
      'name': name,
      'description': description,
      'members': memberIds,
      if (imageUrl != null) 'image': imageUrl,
      'is_public': isPublic,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGroup(
      String groupId, Map<String, dynamic> data) async {
    final res =
        await dioClient.put(AppEndpoints.updateGroup(groupId), data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> leaveGroup(String groupId) async {
    await dioClient.post(AppEndpoints.leaveGroup(groupId));
  }

  Future<void> deleteGroup(String groupId) async {
    await dioClient.delete(AppEndpoints.deleteGroup(groupId));
  }

  Future<Map<String, dynamic>?> joinGroupByInviteCode(String code) async {
    final res = await dioClient.post(AppEndpoints.joinGroup,
        data: {'invite_code': code});
    return res.data as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getGroupByInviteCode(String code) async {
    final res = await dioClient.get(AppEndpoints.groupByInviteCode(code));
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<void> addGroupMember(String groupId, String userId) async {
    await dioClient.post(AppEndpoints.addGroupMember(groupId),
        data: {'user_id': userId});
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await dioClient.post(AppEndpoints.removeGroupMember(groupId),
        data: {'user_id': userId});
  }

  Future<void> promoteGroupMember(String groupId, String userId,
      {Map<String, dynamic>? permissions, String? adminTitle}) async {
    await dioClient.post(AppEndpoints.promoteGroupMember(groupId), data: {
      'user_id': userId,
      if (permissions != null) ...permissions,
      if (adminTitle != null) 'admin_title': adminTitle,
    });
  }

  Future<void> updateGroupAdminPermissions(
      String groupId, String memberId, Map<String, dynamic> permissions) async {
    await dioClient.post('/v1/groups/$groupId/members/admin-permissions', data: {
      'user_id': memberId,
      ...permissions,
    });
  }

  Future<void> demoteGroupMember(String groupId, String userId) async {
    await dioClient.post(AppEndpoints.demoteGroupMember(groupId),
        data: {'user_id': userId});
  }

  Future<void> banGroupMember(
      String groupId, String userId, String? reason) async {
    await dioClient.post(AppEndpoints.banGroupMember(groupId),
        data: {'user_id': userId, if (reason != null) 'reason': reason});
  }

  Future<void> unbanGroupMember(String groupId, String userId) async {
    await dioClient.post(AppEndpoints.unbanGroupMember(groupId),
        data: {'user_id': userId});
  }

  Future<List<Map<String, dynamic>>> getGroupBannedUsers(String groupId) async {
    final res =
        await dioClient.get(AppEndpoints.groupBannedUsers(groupId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<void> muteGroupMember(
      String groupId, String userId, String? duration) async {
    await dioClient.post(AppEndpoints.muteGroupMember(groupId), data: {
      'user_id': userId,
      if (duration != null) 'duration': duration,
    });
  }

  Future<void> unmuteGroupMember(String groupId, String userId) async {
    await dioClient.post(AppEndpoints.unmuteGroupMember(groupId),
        data: {'user_id': userId});
  }

  Future<void> kickGroupMember(String groupId, String userId) async {
    await dioClient.post(AppEndpoints.removeGroupMember(groupId),
        data: {'user_id': userId});
  }

  Future<Map<String, dynamic>?> getGroupPermissions(String groupId, {String? userId}) async {
    final res = await dioClient.get(
      AppEndpoints.groupPermissions(groupId),
      queryParameters: {if (userId != null) 'userId': userId},
    );
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<void> updateGroupPermissions(
      String groupId, Map<String, dynamic> perms) async {
    await dioClient.put(AppEndpoints.groupPermissions(groupId), data: perms);
  }

  Future<List<Map<String, dynamic>>> getGroupJoinRequests(
      String groupId) async {
    final res =
        await dioClient.get(AppEndpoints.groupJoinRequests(groupId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<void> approveJoinRequest(String requestId) async {
    await dioClient.post(AppEndpoints.approveJoinRequest(requestId));
  }

  Future<void> rejectJoinRequest(String requestId) async {
    await dioClient.post(AppEndpoints.rejectJoinRequest(requestId));
  }

  Future<List<Map<String, dynamic>>> getGroupPinnedMessages(
      String groupId) async {
    final res =
        await dioClient.get(AppEndpoints.groupPinnedMessages(groupId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<void> pinGroupMessage(
      String groupId, String messageId) async {
    await dioClient.post(AppEndpoints.pinGroupMessage(groupId, messageId));
  }

  Future<void> unpinGroupMessage(
      String groupId, String messageId) async {
    await dioClient.delete(AppEndpoints.pinGroupMessage(groupId, messageId));
  }

  Future<List<Map<String, dynamic>>> getGroupActionLog(
      String groupId) async {
    final res = await dioClient.get(AppEndpoints.groupActionLog(groupId));
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<Map<String, dynamic>?> editGroupMessage(
      String messageId, String newContent) async {
    final res = await dioClient.put(
        AppEndpoints.editGroupMessage(messageId),
        data: {'content': newContent});
    return res.data as Map<String, dynamic>?;
  }

  Future<void> deleteGroupMessageRest(
      String messageId, String deleteType) async {
    await dioClient.delete(AppEndpoints.deleteGroupMessage(messageId),
        data: {'delete_type': deleteType});
  }

  Future<Map<String, dynamic>?> markGroupRead(String groupId) async {
    final res = await dioClient.post(AppEndpoints.markGroupRead(groupId));
    return res.data as Map<String, dynamic>?;
  }

  // ── Topics ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGroupTopics(String groupId,
      {String? status, int page = 1, int limit = 20}) async {
    final res = await dioClient.get(
      AppEndpoints.groupTopics(groupId),
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data['topics'] is List) {
      return List<Map<String, dynamic>>.from(data['topics'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getGroupTopic(
      String groupId, String topicId) async {
    final res =
        await dioClient.get(AppEndpoints.groupTopic(groupId, topicId));
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> createGroupTopic({
    required String groupId,
    required String title,
    required String content,
    String? mediaUrl,
    String? type,
    List<String>? options, // for poll topics
  }) async {
    final res = await dioClient.post(AppEndpoints.groupTopics(groupId), data: {
      'title': title,
      'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (type != null) 'type': type,
      if (options != null) 'options': options,
    });
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<void> updateGroupTopicStatus(
      String groupId, String topicId, String status) async {
    await dioClient.patch(
        AppEndpoints.groupTopicStatus(groupId, topicId),
        data: {'status': status});
  }

  Future<void> pinGroupTopic(
      String groupId, String topicId, bool pinned) async {
    await dioClient.post(AppEndpoints.groupTopicPin(groupId, topicId),
        data: {'pinned': pinned});
  }

  Future<void> voteOnTopic(
      String groupId, String topicId, String optionId) async {
    await dioClient.post(AppEndpoints.groupTopicVote(groupId, topicId),
        data: {'option_id': optionId});
  }

  Future<List<Map<String, dynamic>>> getTopicReplies(
      String groupId, String topicId,
      {int page = 1, int limit = 20}) async {
    final res = await dioClient.get(
      AppEndpoints.groupTopicReplies(groupId, topicId),
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  Future<Map<String, dynamic>?> createTopicReply({
    required String groupId,
    required String topicId,
    required String content,
    String? mediaUrl,
  }) async {
    final res = await dioClient.post(
        AppEndpoints.groupTopicReplies(groupId, topicId),
        data: {
          'content': content,
          if (mediaUrl != null) 'media_url': mediaUrl,
        });
    return res.data['data'] as Map<String, dynamic>?;
  }

  // ── Spam protection ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSpamProtectionSettings(
      String userId) async {
    try {
      final res = await dioClient
          .get('/v1/spam-protection/settings/$userId');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateSpamProtectionSettings(
      String userId, Map<String, dynamic> settings) async {
    await dioClient.put('/v1/spam-protection/settings/$userId',
        data: settings);
  }

  // ── Group rules ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getGroupRules(String groupId) async {
    try {
      final res = await dioClient.get(AppEndpoints.groupRules(groupId));
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateGroupRules(String groupId, String? rules) async {
    await dioClient.put(AppEndpoints.groupRules(groupId), data: {'rules': rules});
  }

  // ── Disappearing messages ─────────────────────────────────────────────────
  Future<void> setGroupDisappearingMessages(String groupId, int seconds) async {
    await dioClient.post(AppEndpoints.groupDisappearingMessages(groupId), data: {
      'timer': seconds,
    });
  }

  // ── Member search ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchGroupMembers(
      String groupId, String query, {int page = 1, int limit = 50}) async {
    try {
      final res = await dioClient.get(
        AppEndpoints.groupMembers(groupId),
        queryParameters: {'q': query, 'page': page, 'limit': limit},
      );
      final data = res.data['data'];
      if (data is Map && data['members'] is List) {
        return List<Map<String, dynamic>>.from(data['members'] as List);
      }
      if (data is List) return List<Map<String, dynamic>>.from(data);
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Pinned messages (private chat) ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPinnedMessages(
      String conversationId) async {
    try {
      final res = await dioClient
          .get('/v1/chat/conversations/$conversationId/pinned');
      final data = res.data['data'];
      if (data is List) return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  Future<void> pinMessage(String conversationId, String messageId) async {
    await dioClient.post(
        '/v1/chat/conversations/$conversationId/messages/$messageId/pin');
  }

  Future<void> unpinMessage(String conversationId, String messageId) async {
    await dioClient.delete(
        '/v1/chat/conversations/$conversationId/messages/$messageId/pin');
  }

  // ── Welcome message ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getGroupWelcomeMessage(
      String groupId) async {
    try {
      final res =
          await dioClient.get('/v1/groups/$groupId/welcome-message');
      return res.data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setGroupWelcomeMessage(
      String groupId, String message) async {
    await dioClient.post('/v1/groups/$groupId/welcome-message',
        data: {'message': message});
  }

  // ── Public groups ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPublicGroups({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
  }) async {
    final res = await dioClient.get(
      AppEndpoints.publicGroupsList,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null) 'category': category,
      },
    );
    final data = res.data['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data['groups'] is List) {
      return List<Map<String, dynamic>>.from(data['groups'] as List);
    }
    return [];
  }
}

final chatApiService = ChatApiService();
