import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../database/app_database.dart';
import '../api/dio_client.dart';
import '../api/app_endpoints.dart';
import 'auth_provider.dart';

// ── ChatMessage model ─────────────────────────────────────────────────────────
// In-memory model mirroring what the RN chatStore keeps per conversation.
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? receiverId;
  final String senderName;
  final String? senderPic;
  final String? senderUsername;
  final bool senderIsVerified;
  final String? senderVerificationBadge;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final Map<String, dynamic>? mediaData;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? linkPreview;
  final List<Map<String, dynamic>>? reactions;
  final String? replyToId;
  final Map<String, dynamic>? replyTo;
  final bool isRead;
  final String? readAt;
  final String status; // pending | sent | delivered | read | failed
  final bool isDeleted;
  final bool isEdited;
  final String? editedAt;
  final DateTime createdAt;
  final String syncStatus; // pending_sync | synced | sync_failed
  final String? tempId;
  final bool isSystem;
  final String? groupId;
  final Map<String, dynamic>? pollData;
  final bool isForwarded;
  final bool isPinned;
  final String? translatedContent;
  final String? translatedLanguage;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    this.senderName = '',
    this.senderPic,
    this.senderUsername,
    this.senderIsVerified = false,
    this.senderVerificationBadge,
    this.content = '',
    this.messageType = 'text',
    this.mediaUrl,
    this.mediaData,
    this.metadata,
    this.linkPreview,
    this.reactions,
    this.replyToId,
    this.replyTo,
    this.isRead = false,
    this.readAt,
    this.status = 'pending',
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    required this.createdAt,
    this.syncStatus = 'pending_sync',
    this.tempId,
    this.isSystem = false,
    this.groupId,
    this.pollData,
    this.isForwarded = false,
    this.isPinned = false,
    this.translatedContent,
    this.translatedLanguage,
  });

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? senderPic,
    String? senderUsername,
    bool? senderIsVerified,
    String? senderVerificationBadge,
    String? content,
    String? messageType,
    String? mediaUrl,
    Map<String, dynamic>? mediaData,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? linkPreview,
    List<Map<String, dynamic>>? reactions,
    String? replyToId,
    Map<String, dynamic>? replyTo,
    bool? isRead,
    String? readAt,
    String? status,
    bool? isDeleted,
    bool? isEdited,
    String? editedAt,
    DateTime? createdAt,
    String? syncStatus,
    String? tempId,
    bool? isSystem,
    String? groupId,
    Map<String, dynamic>? pollData,
    bool? isForwarded,
    bool? isPinned,
    String? translatedContent,
    String? translatedLanguage,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        receiverId: receiverId ?? this.receiverId,
        senderName: senderName ?? this.senderName,
        senderPic: senderPic ?? this.senderPic,
        senderUsername: senderUsername ?? this.senderUsername,
        senderIsVerified: senderIsVerified ?? this.senderIsVerified,
        senderVerificationBadge:
            senderVerificationBadge ?? this.senderVerificationBadge,
        content: content ?? this.content,
        messageType: messageType ?? this.messageType,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        mediaData: mediaData ?? this.mediaData,
        metadata: metadata ?? this.metadata,
        linkPreview: linkPreview ?? this.linkPreview,
        reactions: reactions ?? this.reactions,
        replyToId: replyToId ?? this.replyToId,
        replyTo: replyTo ?? this.replyTo,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        status: status ?? this.status,
        isDeleted: isDeleted ?? this.isDeleted,
        isEdited: isEdited ?? this.isEdited,
        editedAt: editedAt ?? this.editedAt,
        createdAt: createdAt ?? this.createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
        tempId: tempId ?? this.tempId,
        isSystem: isSystem ?? this.isSystem,
        groupId: groupId ?? this.groupId,
        pollData: pollData ?? this.pollData,
        isForwarded: isForwarded ?? this.isForwarded,
        isPinned: isPinned ?? this.isPinned,
        translatedContent: translatedContent ?? this.translatedContent,
        translatedLanguage: translatedLanguage ?? this.translatedLanguage,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseJsonField(dynamic val) {
      if (val == null) return null;
      if (val is Map<String, dynamic>) return val;
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return null;
    }

    List<Map<String, dynamic>>? parseReactions(dynamic val) {
      if (val == null) return null;
      List? list;
      if (val is List) {
        list = val;
      } else if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) list = decoded;
        } catch (_) {}
      }
      if (list == null) return null;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? json['group_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      receiverId: json['receiver_id']?.toString(),
      senderName: json['sender_name'] ?? json['senderName'] ?? '',
      senderPic: json['sender_pic'] ?? json['senderPic'] ?? json['avatar'],
      senderUsername: json['sender_username'] ?? json['username'],
      senderIsVerified: json['is_verified'] == true || json['sender_is_verified'] == true,
      senderVerificationBadge: json['verification_badge'],
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? json['type'] ?? 'text',
      mediaUrl: json['media_url'],
      mediaData: parseJsonField(json['media_data']),
      metadata: parseJsonField(json['metadata']),
      linkPreview: parseJsonField(json['link_preview']),
      reactions: parseReactions(json['reactions']),
      replyToId: json['reply_to_id']?.toString(),
      replyTo: parseJsonField(json['reply_to']),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      readAt: json['read_at']?.toString(),
      status: json['status'] ?? 'sent',
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
      isEdited: json['is_edited'] == true || json['is_edited'] == 1,
      editedAt: json['edited_at']?.toString(),
      createdAt: parseDate(json['created_at']),
      syncStatus: json['sync_status'] ?? 'synced',
      tempId: json['temp_id']?.toString() ?? json['tempId']?.toString(),
      isSystem: json['is_system'] == true,
      groupId: json['group_id']?.toString(),
      pollData: parseJsonField(json['poll_data']),
      isForwarded: json['is_forwarded'] == true,
      isPinned: json['is_pinned'] == true,
      translatedContent: json['translated_content'],
      translatedLanguage: json['translated_language'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_name': senderName,
        'sender_pic': senderPic,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'media_data': mediaData != null ? jsonEncode(mediaData) : null,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
        'link_preview': linkPreview != null ? jsonEncode(linkPreview) : null,
        'reactions': reactions != null ? jsonEncode(reactions) : null,
        'reply_to_id': replyToId,
        'reply_to': replyTo != null ? jsonEncode(replyTo) : null,
        'is_read': isRead,
        'status': status,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'sync_status': syncStatus,
        'temp_id': tempId,
        'group_id': groupId,
        'poll_data': pollData != null ? jsonEncode(pollData) : null,
      };
}

// ── ChatConversation model ────────────────────────────────────────────────────
class ChatConversation {
  final String id;
  final String type; // private | group | channel
  final String name;
  final String? profilePic;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final String? lastMessageTime;
  final bool lastMessageIsRead;
  final String? lastMessageStatus;
  final int unreadCount;
  final bool isMuted;
  final String status; // active | request_pending | blocked
  final Map<String, dynamic>? otherUser;
  final String? otherUserId;
  final String? initiatorId;
  final bool iBlockedThem;
  final bool theyBlockedMe;
  final int sentMessageCount;
  final String? lastReactionEmoji;
  final String? lastReactionAt;
  final String? lastReactionUserId;
  final String? lastReactionMessageContent;
  final DateTime? updatedAt;
  final bool? isLive; // group is in live audio room

  const ChatConversation({
    required this.id,
    this.type = 'private',
    this.name = '',
    this.profilePic,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageTime,
    this.lastMessageIsRead = false,
    this.lastMessageStatus,
    this.unreadCount = 0,
    this.isMuted = false,
    this.status = 'active',
    this.otherUser,
    this.otherUserId,
    this.initiatorId,
    this.iBlockedThem = false,
    this.theyBlockedMe = false,
    this.sentMessageCount = 0,
    this.lastReactionEmoji,
    this.lastReactionAt,
    this.lastReactionUserId,
    this.lastReactionMessageContent,
    this.updatedAt,
    this.isLive,
  });

  ChatConversation copyWith({
    String? id,
    String? type,
    String? name,
    String? profilePic,
    String? lastMessage,
    String? lastMessageType,
    String? lastMessageSenderId,
    String? lastMessageTime,
    bool? lastMessageIsRead,
    String? lastMessageStatus,
    int? unreadCount,
    bool? isMuted,
    String? status,
    Map<String, dynamic>? otherUser,
    String? otherUserId,
    String? initiatorId,
    bool? iBlockedThem,
    bool? theyBlockedMe,
    int? sentMessageCount,
    String? lastReactionEmoji,
    String? lastReactionAt,
    String? lastReactionUserId,
    String? lastReactionMessageContent,
    DateTime? updatedAt,
    bool? isLive,
  }) =>
      ChatConversation(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        profilePic: profilePic ?? this.profilePic,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageType: lastMessageType ?? this.lastMessageType,
        lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
        lastMessageTime: lastMessageTime ?? this.lastMessageTime,
        lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
        lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
        unreadCount: unreadCount ?? this.unreadCount,
        isMuted: isMuted ?? this.isMuted,
        status: status ?? this.status,
        otherUser: otherUser ?? this.otherUser,
        otherUserId: otherUserId ?? this.otherUserId,
        initiatorId: initiatorId ?? this.initiatorId,
        iBlockedThem: iBlockedThem ?? this.iBlockedThem,
        theyBlockedMe: theyBlockedMe ?? this.theyBlockedMe,
        sentMessageCount: sentMessageCount ?? this.sentMessageCount,
        lastReactionEmoji: lastReactionEmoji ?? this.lastReactionEmoji,
        lastReactionAt: lastReactionAt ?? this.lastReactionAt,
        lastReactionUserId: lastReactionUserId ?? this.lastReactionUserId,
        lastReactionMessageContent:
            lastReactionMessageContent ?? this.lastReactionMessageContent,
        updatedAt: updatedAt ?? this.updatedAt,
        isLive: isLive ?? this.isLive,
      );

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final otherUser = json['other_user'] as Map<String, dynamic>?;
    return ChatConversation(
      id: (json['id'] ?? '').toString(),
      type: json['type'] ?? 'private',
      name: otherUser?['name'] ??
          otherUser?['username'] ??
          json['name'] ??
          '',
      profilePic: otherUser?['profile_pic'] ?? json['picture'] ?? json['profile_pic'],
      lastMessage: json['last_message_content'] ?? json['last_message'],
      lastMessageType: json['last_message_type'],
      lastMessageSenderId: json['last_message_sender_id']?.toString(),
      lastMessageTime: json['last_message_time']?.toString(),
      lastMessageIsRead: json['last_message_is_read'] == true,
      lastMessageStatus: json['last_message_status'],
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isMuted: json['is_muted'] == true,
      status: json['status'] ?? 'active',
      otherUser: otherUser,
      otherUserId: otherUser?['id']?.toString() ?? json['other_user_id']?.toString(),
      initiatorId: json['initiator_id']?.toString(),
      iBlockedThem: json['i_blocked_them'] == true || json['i_blocked_them'] == 1,
      theyBlockedMe: json['they_blocked_me'] == true || json['they_blocked_me'] == 1,
      sentMessageCount: (json['sent_message_count'] as num?)?.toInt() ?? 0,
      lastReactionEmoji: json['last_reaction_emoji'],
      lastReactionAt: json['last_reaction_at']?.toString(),
      lastReactionUserId: json['last_reaction_user_id']?.toString(),
      lastReactionMessageContent: json['last_reaction_message_content'],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      isLive: json['is_live'] == true,
    );
  }
}

// ── ChatState ─────────────────────────────────────────────────────────────────
class ChatState {
  final List<ChatConversation> conversations;
  final List<ChatConversation> groups;
  final Map<String, List<ChatMessage>> messages; // conversationId -> messages
  final Set<String> onlineUsers;
  final Map<String, Set<String>> typingUsers; // conversationId -> Set<userId>
  final bool isConnected;
  final String? activeConversationId;
  final Set<String> mutedChats; // other user IDs
  final Map<String, String> mutedGroups; // groupId -> mute type
  final bool isSyncing;
  final int pendingActionCount;

  const ChatState({
    this.conversations = const [],
    this.groups = const [],
    this.messages = const {},
    this.onlineUsers = const {},
    this.typingUsers = const {},
    this.isConnected = false,
    this.activeConversationId,
    this.mutedChats = const {},
    this.mutedGroups = const {},
    this.isSyncing = false,
    this.pendingActionCount = 0,
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    List<ChatConversation>? groups,
    Map<String, List<ChatMessage>>? messages,
    Set<String>? onlineUsers,
    Map<String, Set<String>>? typingUsers,
    bool? isConnected,
    String? activeConversationId,
    bool clearActiveConversation = false,
    Set<String>? mutedChats,
    Map<String, String>? mutedGroups,
    bool? isSyncing,
    int? pendingActionCount,
  }) =>
      ChatState(
        conversations: conversations ?? this.conversations,
        groups: groups ?? this.groups,
        messages: messages ?? this.messages,
        onlineUsers: onlineUsers ?? this.onlineUsers,
        typingUsers: typingUsers ?? this.typingUsers,
        isConnected: isConnected ?? this.isConnected,
        activeConversationId: clearActiveConversation
            ? null
            : activeConversationId ?? this.activeConversationId,
        mutedChats: mutedChats ?? this.mutedChats,
        mutedGroups: mutedGroups ?? this.mutedGroups,
        isSyncing: isSyncing ?? this.isSyncing,
        pendingActionCount: pendingActionCount ?? this.pendingActionCount,
      );
}

// ── ChatNotifier ──────────────────────────────────────────────────────────────
// Riverpod equivalent of the RN Zustand chatStore.
// All socket events and actions funnel through this single notifier.
class ChatNotifier extends StateNotifier<ChatState> {
  final AppDatabase _db;
  final Ref _ref;
  io.Socket? _socket;
  String? _currentUserId;

  // Reverse index: messageId -> conversationId (O(1) delete/patch)
  final Map<String, String> _messageOwnerMap = {};

  // Deduplication set — prevents processing the same socket event twice
  final Set<String> _processedMessageIds = {};

  // Reaction batch buffer per conversation
  final Map<String, Timer> _reactionBatchTimers = {};
  final Map<String, Map<String, List<Map<String, dynamic>>>> _pendingReactions = {};

  // Mark-read debounce
  String? _pendingMarkReadConvId;
  List<String> _pendingMarkReadIds = [];
  Timer? _markReadDebounceTimer;

  ChatNotifier(this._db, this._ref) : super(const ChatState());

  io.Socket? get socket => _socket;
  String? get currentUserId => _currentUserId;

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init(io.Socket socket, String userId) async {
    _socket = socket;
    _currentUserId = userId;
    _setupSocketListeners();
    await _loadConversationsFromDb();
  }

  Future<void> _loadConversationsFromDb() async {
    try {
      final convRows = await _db.chatDao.getConversations();
      final convs = convRows.map(_conversationFromRow).toList();
      state = state.copyWith(conversations: convs);
    } catch (_) {}
  }

  ChatConversation _conversationFromRow(Conversation row) => ChatConversation(
        id: row.id,
        type: row.type,
        name: row.name,
        profilePic: row.profilePic,
        lastMessage: row.lastMessage,
        lastMessageType: row.lastMessageType,
        lastMessageSenderId: row.lastMessageSenderId,
        lastMessageTime: row.lastMessageTime,
        lastMessageIsRead: row.lastMessageIsRead,
        lastMessageStatus: row.lastMessageStatus,
        unreadCount: row.unreadCount,
        isMuted: row.isMuted,
        status: row.status,
        otherUserId: row.otherUserId,
        initiatorId: row.initiatorId,
        iBlockedThem: row.iBlockedThem,
        theyBlockedMe: row.theyBlockedMe,
        sentMessageCount: row.sentMessageCount,
        lastReactionEmoji: row.lastReactionEmoji,
        lastReactionAt: row.lastReactionAt,
        lastReactionUserId: row.lastReactionUserId,
        lastReactionMessageContent: row.lastReactionMessageContent,
      );

  // ── Socket listeners ────────────────────────────────────────────────────────
  void _setupSocketListeners() {
    final s = _socket;
    if (s == null) return;

    s.on('connect', (_) {
      state = state.copyWith(isConnected: true);
    });

    s.on('disconnect', (_) {
      state = state.copyWith(isConnected: false);
    });

    s.on('join_success', (data) {
      // Trigger pending action sync when socket is ready
    });

    s.on('new_message', (data) => _handleNewMessage(data));
    s.on('message_sent', (data) => _handleMessageSent(data));
    s.on('message_deleted', (data) => _handleMessageDeleted(data));
    s.on('message_edited', (data) => _handleMessageEdited(data));
    s.on('message_read', (data) => _handleMessageRead(data));
    s.on('messages_read', (data) => _handleMessagesRead(data));
    s.on('reaction_updated', (data) => _handleReactionUpdated(data));
    s.on('typing_start', (data) => _handleTyping(data, true));
    s.on('typing_stop', (data) => _handleTyping(data, false));
    s.on('user_online', (data) => _handlePresence(data, true));
    s.on('user_offline', (data) => _handlePresence(data, false));
    s.on('conversation_deleted', (data) => _handleConversationDeleted(data));
    s.on('new_conversation', (data) => _handleNewConversation(data));
    s.on('conversation_accepted', (data) => _handleConversationAccepted(data));

    // Group events
    s.on('new_group_message', (data) => _handleNewGroupMessage(data));
    s.on('group_message_sent', (data) => _handleGroupMessageSent(data));
    s.on('group_message_deleted', (data) => _handleGroupMessageDeleted(data));
    s.on('group_message_edited', (data) => _handleGroupMessageEdited(data));
    s.on('group_message_read', (data) => _handleGroupMessageRead(data));
    s.on('group_reaction_updated', (data) => _handleGroupReactionUpdated(data));
    s.on('group_member_joined', (_) => _refreshGroups());
    s.on('group_member_left', (_) => _refreshGroups());
    s.on('group_updated', (_) => _refreshGroups());
    s.on('group_dissolved', (data) => _handleGroupDissolved(data));
    s.on('online_users', (data) => _handleOnlineUsersList(data));
  }

  // ── Private message handlers ─────────────────────────────────────────────────
  void _handleNewMessage(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final msg = ChatMessage.fromJson(d);

    if (_processedMessageIds.contains(msg.id)) return;
    _processedMessageIds.add(msg.id);
    if (_processedMessageIds.length > 500) {
      _processedMessageIds.clear();
    }

    _addMessage(msg.conversationId, msg);
    _updateConversationFromMessage(msg, isIncoming: true);
    _saveMessageToDb(msg);
  }

  void _handleMessageSent(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final tempId = d['temp_id']?.toString() ?? d['tempId']?.toString();
    final serverId = d['id']?.toString() ?? d['message_id']?.toString();
    final convId = d['conversation_id']?.toString();
    if (tempId == null || serverId == null || convId == null) return;

    _swapTempMessage(convId, tempId, serverId, d);
  }

  void _handleMessageDeleted(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final msgId = d['message_id']?.toString() ?? d['id']?.toString();
    if (msgId == null) return;

    final convId = _messageOwnerMap[msgId];
    if (convId != null) {
      _patchMessage(convId, msgId, (m) => m.copyWith(isDeleted: true));
      _messageOwnerMap.remove(msgId);
    }
  }

  void _handleMessageEdited(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final msgId = d['message_id']?.toString() ?? d['id']?.toString();
    final newContent = d['new_content']?.toString() ?? d['content']?.toString();
    if (msgId == null || newContent == null) return;

    final convId = _messageOwnerMap[msgId];
    if (convId != null) {
      _patchMessage(convId, msgId,
          (m) => m.copyWith(content: newContent, isEdited: true));
    }
  }

  void _handleMessageRead(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final convId = d['conversation_id']?.toString();
    if (convId == null) return;

    final msgs = state.messages[convId];
    if (msgs == null) return;

    final updated = msgs.map((m) {
      if (m.senderId == _currentUserId && !m.isRead) {
        return m.copyWith(isRead: true, status: 'read');
      }
      return m;
    }).toList();

    state = state.copyWith(
        messages: {...state.messages, convId: updated});
  }

  void _handleMessagesRead(dynamic data) => _handleMessageRead(data);

  void _handleReactionUpdated(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final msgId = d['message_id']?.toString();
    if (msgId == null) return;

    // Batch reaction updates — flush after 33ms (Telegram cadence)
    final convId = _messageOwnerMap[msgId];
    if (convId == null) return;

    _pendingReactions.putIfAbsent(convId, () => {})[msgId] =
        (d['reactions'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    _reactionBatchTimers[convId]?.cancel();
    _reactionBatchTimers[convId] = Timer(const Duration(milliseconds: 33), () {
      final pending = _pendingReactions.remove(convId);
      if (pending == null) return;
      _reactionBatchTimers.remove(convId);

      final msgs = state.messages[convId];
      if (msgs == null) return;
      final updated = msgs.map((m) {
        final r = pending[m.id];
        if (r != null) return m.copyWith(reactions: r);
        return m;
      }).toList();
      state = state.copyWith(
          messages: {...state.messages, convId: updated});
    });
  }

  void _handleTyping(dynamic data, bool isTyping) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final userId = d['user_id']?.toString() ?? d['userId']?.toString();
    final convId = d['conversation_id']?.toString() ?? d['conversationId']?.toString();
    if (userId == null || convId == null || userId == _currentUserId) return;

    final current = Map<String, Set<String>>.from(state.typingUsers);
    final set = Set<String>.from(current[convId] ?? {});
    if (isTyping) {
      set.add(userId);
    } else {
      set.remove(userId);
    }
    current[convId] = set;
    state = state.copyWith(typingUsers: current);
  }

  void _handlePresence(dynamic data, bool isOnline) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final userId = (d['user_id'] ?? d['userId'] ?? d['id'])?.toString();
    if (userId == null) return;

    final updated = Set<String>.from(state.onlineUsers);
    if (isOnline) {
      updated.add(userId);
    } else {
      updated.remove(userId);
    }
    state = state.copyWith(onlineUsers: updated);
  }

  void _handleOnlineUsersList(dynamic data) {
    if (data == null) return;
    List<dynamic> userIds = [];
    if (data is List) {
      userIds = data;
    } else if (data is Map) {
      userIds = (data['users'] ?? data['online_users'] ?? []) as List<dynamic>;
    }
    state = state.copyWith(
        onlineUsers: userIds.map((e) => e.toString()).toSet());
  }

  void _handleConversationDeleted(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final convId = d['conversation_id']?.toString();
    if (convId == null) return;
    _removeConversation(convId);
  }

  void _handleNewConversation(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final conv = ChatConversation.fromJson(d);
    _upsertConversation(conv);
  }

  void _handleConversationAccepted(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final convId = d['conversation_id']?.toString();
    if (convId == null) return;
    final idx = state.conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) return;
    final updated = List<ChatConversation>.from(state.conversations);
    updated[idx] = updated[idx].copyWith(status: 'active');
    state = state.copyWith(conversations: updated);
  }

  // ── Group message handlers ────────────────────────────────────────────────────
  void _handleNewGroupMessage(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final msg = ChatMessage.fromJson(d);
    if (_processedMessageIds.contains(msg.id)) return;
    _processedMessageIds.add(msg.id);
    _addMessage(msg.conversationId, msg);
    _updateGroupFromMessage(msg, isIncoming: true);
  }

  void _handleGroupMessageSent(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final tempId = d['temp_id']?.toString() ?? d['tempId']?.toString();
    final serverId = d['id']?.toString();
    final groupId = d['group_id']?.toString();
    if (tempId == null || serverId == null || groupId == null) return;
    _swapTempMessage(groupId, tempId, serverId, d);
  }

  void _handleGroupMessageDeleted(dynamic data) => _handleMessageDeleted(data);
  void _handleGroupMessageEdited(dynamic data) => _handleMessageEdited(data);
  void _handleGroupMessageRead(dynamic data) => _handleMessageRead(data);
  void _handleGroupReactionUpdated(dynamic data) => _handleReactionUpdated(data);

  void _handleGroupDissolved(dynamic data) {
    if (data == null) return;
    final d = Map<String, dynamic>.from(data as Map);
    final groupId = d['group_id']?.toString();
    if (groupId == null) return;
    final updated = state.groups.where((g) => g.id != groupId).toList();
    state = state.copyWith(groups: updated);
  }

  Future<void> _refreshGroups() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final res = await dioClient.get(AppEndpoints.userGroups(uid));
      final data = res.data['data'];
      final list = data is List ? data : (data is Map ? data['groups'] as List? ?? [] : []);
      final groups = (list as List)
          .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(groups: groups);
    } catch (_) {}
  }

  // ── Message helpers ───────────────────────────────────────────────────────────
  void _addMessage(String convId, ChatMessage msg) {
    final existing = state.messages[convId] ?? [];

    // Primary dedup
    if (existing.any((m) => m.id == msg.id)) return;

    // Secondary dedup: skip server-confirmed if a matching temp optimistic exists
    if (!msg.id.startsWith('temp_') &&
        msg.content.isNotEmpty &&
        existing.any((m) =>
            m.id.startsWith('temp_') &&
            m.senderId == msg.senderId &&
            m.content == msg.content)) {
      return;
    }

    // Insert in sorted position (oldest-first)
    final list = List<ChatMessage>.from(existing);
    final ts = msg.createdAt.millisecondsSinceEpoch;
    int insertAt = list.indexWhere((m) => m.createdAt.millisecondsSinceEpoch > ts);
    if (insertAt == -1) insertAt = list.length;
    list.insert(insertAt, msg);

    // Cap at 100 messages in memory
    final capped = list.length > 100 ? list.sublist(list.length - 100) : list;

    _messageOwnerMap[msg.id] = convId;
    if (msg.tempId != null) _messageOwnerMap[msg.tempId!] = convId;

    state = state.copyWith(messages: {...state.messages, convId: capped});
  }

  void _patchMessage(
      String convId, String msgId, ChatMessage Function(ChatMessage) patch) {
    final msgs = state.messages[convId];
    if (msgs == null) return;
    final updated = msgs.map((m) {
      if (m.id == msgId || m.tempId == msgId) return patch(m);
      return m;
    }).toList();
    state = state.copyWith(messages: {...state.messages, convId: updated});
  }

  void _swapTempMessage(
      String convId, String tempId, String serverId, Map<String, dynamic> d) {
    final msgs = state.messages[convId];
    if (msgs == null) return;

    final idx = msgs.indexWhere((m) => m.id == tempId || m.tempId == tempId);
    if (idx == -1) return;

    final old = msgs[idx];
    final updated = List<ChatMessage>.from(msgs);
    final serverMsg = old.copyWith(
      id: serverId,
      tempId: tempId,
      status: 'sent',
      syncStatus: 'synced',
    );
    updated[idx] = serverMsg;

    _messageOwnerMap.remove(tempId);
    _messageOwnerMap[serverId] = convId;
    _db.chatDao.replaceLocalMessage(tempId,
        _messageToCompanion(serverMsg)).ignore();

    state = state.copyWith(messages: {...state.messages, convId: updated});
  }

  // ── Conversation helpers ──────────────────────────────────────────────────────
  void _upsertConversation(ChatConversation conv) {
    final idx = state.conversations.indexWhere((c) => c.id == conv.id);
    final updated = List<ChatConversation>.from(state.conversations);
    if (idx == -1) {
      updated.insert(0, conv);
    } else {
      updated[idx] = conv;
      if (idx != 0) {
        updated.removeAt(idx);
        updated.insert(0, conv);
      }
    }
    state = state.copyWith(conversations: updated);
  }

  void _removeConversation(String convId) {
    final updated =
        state.conversations.where((c) => c.id != convId).toList();
    state = state.copyWith(conversations: updated);
  }

  void _updateConversationFromMessage(ChatMessage msg,
      {bool isIncoming = false}) {
    final convId = msg.conversationId;
    final idx = state.conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) return;

    final conv = state.conversations[idx];
    final updated = List<ChatConversation>.from(state.conversations);
    updated[idx] = conv.copyWith(
      lastMessage: msg.content,
      lastMessageType: msg.messageType,
      lastMessageSenderId: msg.senderId,
      lastMessageTime: msg.createdAt.toIso8601String(),
      lastMessageIsRead: false,
      lastMessageStatus: msg.status,
      unreadCount: isIncoming && msg.senderId != _currentUserId
          ? (conv.unreadCount + 1)
          : conv.unreadCount,
      updatedAt: msg.createdAt,
    );
    if (idx != 0) {
      final c = updated.removeAt(idx);
      updated.insert(0, c);
    }
    state = state.copyWith(conversations: updated);
  }

  void _updateGroupFromMessage(ChatMessage msg, {bool isIncoming = false}) {
    final groupId = msg.conversationId;
    final idx = state.groups.indexWhere((g) => g.id == groupId);
    if (idx == -1) return;

    final group = state.groups[idx];
    final updated = List<ChatConversation>.from(state.groups);
    updated[idx] = group.copyWith(
      lastMessage: msg.content,
      lastMessageType: msg.messageType,
      lastMessageSenderId: msg.senderId,
      lastMessageTime: msg.createdAt.toIso8601String(),
      unreadCount: isIncoming && msg.senderId != _currentUserId
          ? (group.unreadCount + 1)
          : group.unreadCount,
      updatedAt: msg.createdAt,
    );
    state = state.copyWith(groups: updated);
  }

  // ── DB helpers ────────────────────────────────────────────────────────────────
  Future<void> _saveMessageToDb(ChatMessage msg) async {
    try {
      await _db.chatDao.insertMessage(_messageToCompanion(msg));
    } catch (_) {}
  }

  MessagesCompanion _messageToCompanion(ChatMessage msg) => MessagesCompanion.insert(
        id: msg.id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        receiverId: Value(msg.receiverId),
        senderName: Value(msg.senderName),
        senderPic: Value(msg.senderPic),
        senderUsername: Value(msg.senderUsername),
        senderIsVerified: Value(msg.senderIsVerified),
        content: Value(msg.content),
        messageType: Value(msg.messageType),
        mediaUrl: Value(msg.mediaUrl),
        mediaData: Value(
            msg.mediaData != null ? jsonEncode(msg.mediaData) : null),
        metadata: Value(
            msg.metadata != null ? jsonEncode(msg.metadata) : null),
        linkPreview: Value(
            msg.linkPreview != null ? jsonEncode(msg.linkPreview) : null),
        reactions: Value(
            msg.reactions != null ? jsonEncode(msg.reactions) : null),
        replyToId: Value(msg.replyToId),
        replyTo:
            Value(msg.replyTo != null ? jsonEncode(msg.replyTo) : null),
        isRead: Value(msg.isRead),
        status: Value(msg.status),
        isDeleted: Value(msg.isDeleted),
        isEdited: Value(msg.isEdited),
        createdAt: msg.createdAt.millisecondsSinceEpoch,
        syncStatus: Value(msg.syncStatus),
        tempId: Value(msg.tempId),
        isSystem: Value(msg.isSystem),
        groupId: Value(msg.groupId),
        isPinned: Value(msg.isPinned),
      );

  // ── Public API (called by screens) ───────────────────────────────────────────

  void setConversations(List<ChatConversation> convs) {
    state = state.copyWith(conversations: convs);
    // Persist to DB
    _db.chatDao.bulkUpsertConversations(convs
        .map((c) => ConversationsCompanion.insert(
              id: c.id,
              type: Value(c.type),
              name: Value(c.name),
              profilePic: Value(c.profilePic),
              lastMessage: Value(c.lastMessage),
              lastMessageType: Value(c.lastMessageType),
              lastMessageSenderId: Value(c.lastMessageSenderId),
              lastMessageTime: Value(c.lastMessageTime),
              lastMessageIsRead: Value(c.lastMessageIsRead),
              lastMessageStatus: Value(c.lastMessageStatus),
              unreadCount: Value(c.unreadCount),
              isMuted: Value(c.isMuted),
              status: Value(c.status),
              otherUserId: Value(c.otherUserId),
              initiatorId: Value(c.initiatorId),
              iBlockedThem: Value(c.iBlockedThem),
              theyBlockedMe: Value(c.theyBlockedMe),
              sentMessageCount: Value(c.sentMessageCount),
              updatedAt: Value(
                  c.updatedAt?.millisecondsSinceEpoch ??
                  DateTime.now().millisecondsSinceEpoch),
            ))
        .toList()).ignore();
  }

  void setGroups(List<ChatConversation> groups) {
    state = state.copyWith(groups: groups);
  }

  void setMessages(String convId, List<ChatMessage> msgs) {
    for (final m in msgs) {
      _messageOwnerMap[m.id] = convId;
      if (m.tempId != null) _messageOwnerMap[m.tempId!] = convId;
    }
    state = state.copyWith(messages: {...state.messages, convId: msgs});
  }

  void appendOlderMessages(String convId, List<ChatMessage> older) {
    final existing = state.messages[convId] ?? [];
    // older messages go at the front (they are older = smaller timestamp)
    final merged = [...older, ...existing];
    for (final m in older) {
      _messageOwnerMap[m.id] = convId;
    }
    state = state.copyWith(messages: {...state.messages, convId: merged});
  }

  void setActiveConversation(String? convId) {
    state = convId != null
        ? state.copyWith(activeConversationId: convId)
        : state.copyWith(clearActiveConversation: true);
  }

  void setMutedChats(Set<String> muted) {
    state = state.copyWith(mutedChats: muted);
  }

  void setMutedGroups(Map<String, String> muted) {
    state = state.copyWith(mutedGroups: muted);
  }

  // ── Send message ────────────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    Map<String, dynamic>? mediaData,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? linkPreview,
    String? replyToId,
    Map<String, dynamic>? replyTo,
  }) async {
    if (_currentUserId == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${conversationId.hashCode}';
    final now = DateTime.now();

    final optimistic = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: _currentUserId!,
      receiverId: receiverId,
      content: content,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaData: mediaData,
      metadata: metadata,
      linkPreview: linkPreview,
      replyToId: replyToId,
      replyTo: replyTo,
      createdAt: now,
      status: 'pending',
      syncStatus: 'pending_sync',
      tempId: tempId,
    );

    _addMessage(conversationId, optimistic);
    _updateConversationFromMessage(optimistic);
    _saveMessageToDb(optimistic);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', {
        'conversation_id': conversationId,
        'sender_id': _currentUserId,
        'receiver_id': receiverId,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'media_data': mediaData,
        'metadata': metadata,
        'link_preview': linkPreview,
        'reply_to_id': replyToId,
        'replyTo': replyTo,
        'temp_id': tempId,
      });
    } else {
      await _db.chatDao.insertPendingAction('send_message', jsonEncode({
        'conversation_id': conversationId,
        'sender_id': _currentUserId,
        'receiver_id': receiverId,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'temp_id': tempId,
      }));
    }
  }

  // ── Send group message ────────────────────────────────────────────────────────
  Future<void> sendGroupMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    Map<String, dynamic>? mediaData,
    Map<String, dynamic>? metadata,
    String? replyToId,
    Map<String, dynamic>? replyTo,
  }) async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final senderName = prefs.getString('name') ?? '';
    final senderPic = prefs.getString('profile_pic');
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${groupId.hashCode}';
    final now = DateTime.now();

    final optimistic = ChatMessage(
      id: tempId,
      conversationId: groupId,
      senderId: _currentUserId!,
      senderName: senderName,
      senderPic: senderPic,
      content: content,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaData: mediaData,
      metadata: metadata,
      replyToId: replyToId,
      replyTo: replyTo,
      createdAt: now,
      status: 'pending',
      syncStatus: 'pending_sync',
      tempId: tempId,
      groupId: groupId,
    );

    _addMessage(groupId, optimistic);
    _updateGroupFromMessage(optimistic);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_group_message', {
        'group_id': groupId,
        'sender_id': _currentUserId,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'media_data': mediaData,
        'metadata': metadata,
        'reply_to_id': replyToId,
        'replyTo': replyTo,
        'temp_id': tempId,
      });
    }
  }

  // ── Mark as read ────────────────────────────────────────────────────────────
  void markAsRead(String conversationId) {
    if (_socket == null || _currentUserId == null) return;

    // Debounce — batch rapid mark_read events (33ms)
    _pendingMarkReadConvId = conversationId;
    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      final convId = _pendingMarkReadConvId;
      if (convId == null) return;
      _pendingMarkReadConvId = null;

      if (_socket!.connected) {
        _socket!.emit('mark_read',
            {'conversation_id': convId, 'user_id': _currentUserId});
      }

      // Update local state
      _updateUnreadCount(convId, 0);
      _db.chatDao.markConversationRead(convId).ignore();
      _db.chatDao.markAllMessagesRead(convId, _currentUserId!).ignore();
    });
  }

  void _updateUnreadCount(String convId, int count) {
    // Try private conversations
    var idx = state.conversations.indexWhere((c) => c.id == convId);
    if (idx != -1) {
      final updated = List<ChatConversation>.from(state.conversations);
      updated[idx] = updated[idx].copyWith(unreadCount: count);
      state = state.copyWith(conversations: updated);
      return;
    }
    // Try groups
    idx = state.groups.indexWhere((g) => g.id == convId);
    if (idx != -1) {
      final updated = List<ChatConversation>.from(state.groups);
      updated[idx] = updated[idx].copyWith(unreadCount: count);
      state = state.copyWith(groups: updated);
    }
  }

  // ── Typing ──────────────────────────────────────────────────────────────────
  void startTyping(String conversationId) {
    _socket?.emit('typing_start',
        {'conversation_id': conversationId, 'user_id': _currentUserId});
  }

  void stopTyping(String conversationId) {
    _socket?.emit('typing_stop',
        {'conversation_id': conversationId, 'user_id': _currentUserId});
  }

  // ── Delete message ──────────────────────────────────────────────────────────
  Future<void> deleteMessage(String messageId,
      {String deleteType = 'for_me'}) async {
    if (_socket == null || _currentUserId == null) return;

    final convId = _messageOwnerMap[messageId];
    if (convId != null) {
      _patchMessage(convId, messageId, (m) => m.copyWith(isDeleted: true));
      _messageOwnerMap.remove(messageId);
    }

    await _db.chatDao.softDeleteMessage(messageId);

    if (_socket!.connected) {
      _socket!.emit('delete_message', {
        'message_id': messageId,
        'user_id': _currentUserId,
        'delete_type': deleteType,
      });
    }
  }

  // ── Delete group message ────────────────────────────────────────────────────
  Future<void> deleteGroupMessage(String groupId, String messageId,
      {String deleteType = 'for_everyone'}) async {
    if (_socket == null) return;

    final convId = groupId;
    _patchMessage(convId, messageId, (m) => m.copyWith(isDeleted: true));
    _messageOwnerMap.remove(messageId);
    await _db.chatDao.softDeleteMessage(messageId);

    if (_socket!.connected) {
      _socket!.emit('delete_group_message', {
        'group_id': groupId,
        'message_id': messageId,
        'user_id': _currentUserId,
      });
    }
  }

  // ── Delete conversation ──────────────────────────────────────────────────────
  void deleteConversation(String conversationId,
      {String deleteType = 'for_me'}) {
    _socket?.emit('delete_conversation', {
      'conversation_id': conversationId,
      'user_id': _currentUserId,
      'delete_type': deleteType,
    });
    _removeConversation(conversationId);
  }

  // ── Add/remove reaction ─────────────────────────────────────────────────────
  Future<void> toggleReaction(
      String messageId, String emoji, String username) async {
    if (_socket == null || _currentUserId == null) return;

    final convId = _messageOwnerMap[messageId];
    if (convId == null) return;

    final msgs = state.messages[convId];
    if (msgs == null) return;

    final msg = msgs.firstWhere((m) => m.id == messageId,
        orElse: () => throw StateError('not found'));

    final reactions = List<Map<String, dynamic>>.from(msg.reactions ?? []);
    final hasReacted =
        reactions.any((r) => r['user_id'].toString() == _currentUserId && r['emoji'] == emoji);

    if (hasReacted) {
      reactions.removeWhere(
          (r) => r['user_id'].toString() == _currentUserId && r['emoji'] == emoji);
      _socket!.emit('remove_reaction',
          {'message_id': messageId, 'user_id': _currentUserId, 'emoji': emoji});
    } else {
      final prefs = await SharedPreferences.getInstance();
      reactions.add({
        'message_id': messageId,
        'user_id': _currentUserId,
        'username': username,
        'avatar': prefs.getString('profile_pic'),
        'emoji': emoji,
        'created_at': DateTime.now().toIso8601String(),
      });
      _socket!.emit('add_reaction',
          {'message_id': messageId, 'user_id': _currentUserId, 'emoji': emoji});
    }

    _patchMessage(convId, messageId, (m) => m.copyWith(reactions: reactions));
    _db.chatDao.updateMessageReactions(messageId, jsonEncode(reactions)).ignore();
  }

  // ── Join/leave conversation rooms ────────────────────────────────────────────
  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', conversationId);
  }

  void joinGroup(String groupId) {
    _socket?.emit('join_group', {'group_id': groupId});
  }

  void leaveGroup(String groupId) {
    _socket?.emit('leave_group', {'group_id': groupId});
  }

  bool isUserOnline(String userId) => state.onlineUsers.contains(userId);

  bool isUserTyping(String conversationId, String userId) =>
      state.typingUsers[conversationId]?.contains(userId) ?? false;

  Set<String> getTypingUsers(String conversationId) =>
      state.typingUsers[conversationId] ?? {};

  // ── Cleanup ──────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _markReadDebounceTimer?.cancel();
    for (final t in _reactionBatchTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatNotifier(db, ref);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// Per-conversation messages selector — only rebuilds when this conversation's
// messages change, not on every socket event in other conversations.
final conversationMessagesProvider =
    Provider.family<List<ChatMessage>, String>((ref, convId) {
  return ref.watch(chatProvider.select((s) => s.messages[convId] ?? []));
});

// Per-user online status selector
final userOnlineProvider = Provider.family<bool, String>((ref, userId) {
  return ref.watch(chatProvider.select((s) => s.onlineUsers.contains(userId)));
});

// Per-conversation typing indicator
final conversationTypingProvider =
    Provider.family<Set<String>, String>((ref, convId) {
  return ref.watch(chatProvider.select((s) => s.typingUsers[convId] ?? {}));
});

// Conversations list
final conversationsProvider = Provider<List<ChatConversation>>((ref) {
  return ref.watch(chatProvider.select((s) => s.conversations));
});

// Groups list
final groupsProvider = Provider<List<ChatConversation>>((ref) {
  return ref.watch(chatProvider.select((s) => s.groups));
});

// Total unread count across all conversations + groups
final totalUnreadCountProvider = Provider<int>((ref) {
  final convs = ref.watch(conversationsProvider);
  final groups = ref.watch(groupsProvider);
  final mutedChats = ref.watch(chatProvider.select((s) => s.mutedChats));
  final mutedGroups = ref.watch(chatProvider.select((s) => s.mutedGroups));

  int total = 0;
  for (final c in convs) {
    if (!mutedChats.contains(c.otherUserId)) {
      total += c.unreadCount;
    }
  }
  for (final g in groups) {
    if (!mutedGroups.containsKey(g.id)) {
      total += g.unreadCount;
    }
  }
  return total;
});
