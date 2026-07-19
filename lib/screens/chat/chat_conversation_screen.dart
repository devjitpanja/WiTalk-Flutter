import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';
import '../../services/muted_chats_service.dart';
import '../../services/message_sync_manager.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_actions_bottom_sheet.dart';
import '../../widgets/chat/message_reactions.dart';
import '../../widgets/common/verification_badge.dart';

// ── Module-level cache — persists across mounts like RN conversationSyncTimestamps
final _conversationSyncTimestamps = <String, int>{};
const _syncStaleMs = 5 * 60 * 1000; // 5 minutes

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final Map<String, dynamic>? otherUser; // passed as route extra
  final String? conversationStatus;
  final String? initiatorId;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    this.otherUser,
    this.conversationStatus,
    this.initiatorId,
  });

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen>
    with WidgetsBindingObserver {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = ChatInputBarController();
  final _imagePicker = ImagePicker();

  Map<String, dynamic>? _chatPartner;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 50;

  bool _isRecordingVoice = false;
  bool _uploadingMedia = false;
  bool _isMuted = false;
  bool _isBlocked = false;
  bool _theyBlockedMe = false;
  bool _privacyBlocked = false;
  String? _privacyMessage;
  bool _isIncomingRequest = false;
  bool _isOutgoingRequest = false;
  int _sentMessageCount = 0;
  bool _isOnline = false;

  Timer? _typingStopTimer;
  bool _showQuickEmoji = false;
  ChatMessage? _quickEmojiTarget;
  String? _currentUserId;

  // Sorted messages list with date dividers
  List<_ListItem> _listItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _typingStopTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(chatProvider.notifier)
          .setActiveConversation(widget.chatId);
      ref
          .read(chatProvider.notifier)
          .markAsRead(widget.chatId);
    } else if (state == AppLifecycleState.paused) {
      ref
          .read(chatProvider.notifier)
          .setActiveConversation(null);
    }
  }

  Future<void> _init() async {
    final uid = ref.read(authProvider).uid;
    _currentUserId = uid;

    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    // Join conversation room
    ref
        .read(chatProvider.notifier)
        .joinConversation(widget.chatId);
    ref
        .read(chatProvider.notifier)
        .setActiveConversation(widget.chatId);

    // Load from in-memory store first (instant)
    final stored = ref.read(conversationMessagesProvider(widget.chatId));
    if (stored.isNotEmpty) {
      _buildListItems(stored);
      setState(() => _loading = false);
    }

    // Then sync from server if stale
    final lastSync =
        _conversationSyncTimestamps[widget.chatId];
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale =
        lastSync == null || now - lastSync > _syncStaleMs;

    if (isStale) {
      await _loadMessages(reset: true);
      _conversationSyncTimestamps[widget.chatId] = now;
    } else {
      setState(() => _loading = false);
    }

    // Load conversation details if not passed
    if (widget.otherUser == null) {
      await _loadConversationDetail();
    } else {
      _chatPartner = widget.otherUser;
    }

    // Mark as read
    ref.read(chatProvider.notifier).markAsRead(widget.chatId);

    // Mute status
    final mutedChats = await mutedChatsService.getUserMutedChats(uid);
    final otherUserId =
        (_chatPartner?['id'] ?? widget.otherUser?['id'])?.toString();
    if (otherUserId != null) {
      _isMuted = mutedChats
          .any((m) => m['mutedUserId'].toString() == otherUserId);
    }

    // Block/privacy status
    await _checkBlockStatus(uid, otherUserId);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadConversationDetail() async {
    try {
      final data = await chatApiService.getConversation(widget.chatId);
      if (data != null && mounted) {
        setState(() {
          _chatPartner = data['other_user'] as Map<String, dynamic>? ??
              data;
          _isIncomingRequest = data['status'] == 'request_pending' &&
              data['initiator_id'].toString() !=
                  _currentUserId;
          _isOutgoingRequest = data['status'] == 'request_pending' &&
              data['initiator_id'].toString() == _currentUserId;
          _sentMessageCount =
              (data['sent_message_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkBlockStatus(
      String uid, String? otherUserId) async {
    if (otherUserId == null) return;
    try {
      final res = await dioClient.get(
          '${AppEndpoints.checkBlock}/$uid/$otherUserId');
      final data = res.data['data'] as Map<String, dynamic>?;
      if (mounted && data != null) {
        setState(() {
          _isBlocked = data['i_blocked'] == true;
          _theyBlockedMe = data['they_blocked'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages({bool reset = false}) async {
    if (_loadingMore && !reset) return;

    final uid = _currentUserId;
    if (uid == null) return;

    if (reset) {
      _offset = 0;
      _hasMore = true;
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final msgs = await chatApiService.getMessages(
        widget.chatId,
        limit: _pageSize,
        offset: _offset,
        userId: uid,
      );

      final chatMsgs = msgs
          .map((m) => ChatMessage.fromJson(m))
          .toList()
          .reversed
          .toList(); // newest last

      if (reset) {
        ref
            .read(chatProvider.notifier)
            .setMessages(widget.chatId, chatMsgs);
      } else {
        ref
            .read(chatProvider.notifier)
            .appendOlderMessages(widget.chatId, chatMsgs);
      }

      _offset += msgs.length;
      _hasMore = msgs.length >= _pageSize;
    } catch (_) {}

    if (mounted) setState(() => _loadingMore = false);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <=
            _scrollCtrl.position.minScrollExtent + 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadMessages();
    }
  }

  // Build the flat list with date dividers
  void _buildListItems(List<ChatMessage> msgs) {
    final items = <_ListItem>[];
    DateTime? lastDate;

    for (final msg in msgs) {
      if (msg.isDeleted) continue;
      final msgDay = DateTime(
          msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDate == null || msgDay != lastDate) {
        items.add(_ListItem.dateDivider(msg.createdAt));
        lastDate = msgDay;
      }
      items.add(_ListItem.message(msg));
    }
    _listItems = items;
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  // ── Send message ────────────────────────────────────────────────────────────
  Future<void> _handleSend() async {
    final text = _inputCtrl.text.trim();
    final editing = _inputCtrl.editingMessage;
    final replyTo = _inputCtrl.replyingTo;
    final linkPreview = _inputCtrl.composeLinkPreview;

    if (text.isEmpty) return;

    final uid = _currentUserId;
    final partner = _chatPartner;
    if (uid == null || partner == null) return;

    if (editing != null) {
      // Edit message
      _inputCtrl.clearEditing();
      try {
        await chatApiService.editMessage(
          messageId: editing.id,
          userId: uid,
          newContent: text,
        );
        ref
            .read(chatProvider.notifier)
            .deleteMessage(editing.id, deleteType: 'edit');
        // The socket will emit message_edited event to update the UI
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to edit message')));
        }
      }
      return;
    }

    _inputCtrl.clear();
    ref.read(chatProvider.notifier).stopTyping(widget.chatId);

    await ref.read(chatProvider.notifier).sendMessage(
          conversationId: widget.chatId,
          receiverId: partner['id'].toString(),
          content: text,
          messageType: 'text',
          linkPreview: linkPreview,
          replyToId: replyTo?.id,
          replyTo: replyTo != null
              ? {
                  'id': replyTo.id,
                  'content': replyTo.content,
                  'message_type': replyTo.messageType,
                  'sender_id': replyTo.senderId,
                  'sender_name': replyTo.senderName,
                }
              : null,
        );

    _scrollToBottom();

    // Update sent message count for request tracking
    if (_isOutgoingRequest) {
      setState(() => _sentMessageCount++);
    }
  }

  Future<String?> _pickAndSendImage() async {
    final partner = _chatPartner;
    final uid = _currentUserId;
    if (partner == null || uid == null) return null;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return null;

    setState(() => _uploadingMedia = true);
    try {
      final uploadService = UploadService();
      final result = await uploadService.uploadFile(
          File(picked.path), 'image');
      final url = result['url'] as String?;
      if (url == null) return null;

      // Get image dimensions
      final imageFile = File(picked.path);
      final decodedImage = await decodeImageFromList(
          await imageFile.readAsBytes());
      final mediaData = {
        'width': decodedImage.width,
        'height': decodedImage.height,
      };

      await ref.read(chatProvider.notifier).sendMessage(
            conversationId: widget.chatId,
            receiverId: partner['id'].toString(),
            content: '',
            messageType: 'image',
            mediaUrl: url,
            mediaData: mediaData,
          );
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send image')));
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
    return null;
  }

  void _acceptRequest() async {
    try {
      await chatApiService.acceptConversation(widget.chatId);
      if (mounted) {
        setState(() {
          _isIncomingRequest = false;
          _isOutgoingRequest = false;
        });
      }
    } catch (_) {}
  }

  void _deleteRequest() async {
    try {
      await chatApiService.deleteConversation(widget.chatId);
      if (mounted) context.pop();
    } catch (_) {}
  }

  void _toggleBlock() async {
    final uid = _currentUserId;
    final partner = _chatPartner;
    if (uid == null || partner == null) return;

    try {
      if (_isBlocked) {
        await dioClient.post(AppEndpoints.unblockUser,
            data: {'userId': uid, 'blockedUserId': partner['id']});
        setState(() => _isBlocked = false);
      } else {
        await dioClient.post(AppEndpoints.blockUser,
            data: {'userId': uid, 'blockedUserId': partner['id']});
        setState(() => _isBlocked = true);
      }
    } catch (_) {}
  }

  void _onMessageLongPress(ChatMessage message) {
    final uid = _currentUserId;
    final isMyMessage = message.senderId == uid;
    final canDeleteForEveryone = isMyMessage &&
        DateTime.now().difference(message.createdAt).inHours < 24;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick reaction picker
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: QuickEmojiPicker(
              onSelect: (emoji) {
                Navigator.pop(context);
                final username = ref.read(authProvider).uid ?? '';
                ref
                    .read(chatProvider.notifier)
                    .toggleReaction(message.id, emoji, username);
              },
              onMore: () {
                Navigator.pop(context);
                // Full emoji picker TODO
              },
            ),
          ),
          MessageActionsBottomSheet(
            message: message,
            isMyMessage: isMyMessage,
            isPinned: message.isPinned,
            canDeleteForEveryone: canDeleteForEveryone,
            onAction: (action) => _handleMessageAction(action, message),
          ),
        ],
      ),
    );
  }

  void _handleMessageAction(MessageAction action, ChatMessage message) {
    final uid = _currentUserId;
    switch (action) {
      case MessageAction.reply:
        _inputCtrl.setReplyTo(message);
        _inputCtrl.focus();
        break;
      case MessageAction.edit:
        _inputCtrl.setEditing(message);
        break;
      case MessageAction.delete:
        _confirmDelete(message, false);
        break;
      case MessageAction.deleteForEveryone:
        _confirmDelete(message, true);
        break;
      case MessageAction.pin:
        _pinMessage(message, true);
        break;
      case MessageAction.unpin:
        _pinMessage(message, false);
        break;
      case MessageAction.translate:
        _translateMessage(message);
        break;
      default:
        break;
    }
  }

  void _confirmDelete(ChatMessage message, bool forEveryone) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete Message?',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        content: Text(
            forEveryone
                ? 'Delete for everyone?'
                : 'Delete for yourself only?',
            style: TextStyle(
                color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).deleteMessage(
                    message.id,
                    deleteType:
                        forEveryone ? 'for_everyone' : 'for_me',
                  );
            },
            child: Text('Delete',
                style: TextStyle(
                    color: c.error,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _pinMessage(ChatMessage message, bool pin) async {
    try {
      if (pin) {
        await chatApiService.pinMessage(widget.chatId, message.id);
      } else {
        await chatApiService.unpinMessage(widget.chatId, message.id);
      }
    } catch (_) {}
  }

  void _translateMessage(ChatMessage message) async {
    // TODO: show language selector then translate
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = _currentUserId ?? '';

    // Watch messages reactively
    final messages = ref.watch(conversationMessagesProvider(widget.chatId));
    // Rebuild list items when messages change
    _buildListItems(messages);

    final typingUsers =
        ref.watch(conversationTypingProvider(widget.chatId));
    final isPartnerOnline = ref.watch(userOnlineProvider(
        (_chatPartner?['id'] ?? '').toString()));

    final partnerName = _chatPartner?['name'] ??
        _chatPartner?['username'] ??
        widget.otherUser?['name'] ??
        widget.otherUser?['username'] ??
        'Chat';
    final partnerPic = _chatPartner?['profile_pic'] ??
        widget.otherUser?['profile_pic'];
    final isVerified =
        _chatPartner?['is_verified'] == true ||
        widget.otherUser?['is_verified'] == true;
    final verificationBadge =
        _chatPartner?['verification_badge'] ??
        widget.otherUser?['verification_badge'];

    final isTyping = typingUsers.isNotEmpty &&
        !typingUsers.contains(uid);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            final partnerId =
                (_chatPartner?['id'] ?? '').toString();
            if (partnerId.isNotEmpty) {
              context.push('/profile/$partnerId');
            }
          },
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.surface,
                backgroundImage: partnerPic != null
                    ? CachedNetworkImageProvider(partnerPic)
                    : null,
                child: partnerPic == null
                    ? Text(
                        (partnerName.isNotEmpty
                                ? partnerName[0]
                                : '?')
                            .toUpperCase(),
                        style: TextStyle(
                            color: c.text,
                            fontSize: 13,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600))
                    : null,
              ),
              if (isPartnerOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: c.background, width: 1.5),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    partnerName,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isVerified)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: VerificationBadge(
                          isVerified: true,
                          badge: verificationBadge,
                          size: 14),
                    ),
                ]),
                Text(
                  isTyping
                      ? 'typing...'
                      : isPartnerOnline
                          ? 'Online'
                          : 'Offline',
                  style: TextStyle(
                    color: isTyping
                        ? c.primary
                        : c.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Outfit',
                    fontStyle: isTyping
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ]),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.videocam_outlined, color: c.text),
            onPressed: () => context.push(
                '/video-call/${widget.chatId}'),
          ),
          IconButton(
            icon: Icon(Icons.call_outlined, color: c.text),
            onPressed: () => context.push(
                '/voice-call/${widget.chatId}'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: c.text),
            color: c.surface,
            onSelected: _onMenuAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'view_profile',
                child: Text('View Profile',
                    style: TextStyle(
                        color: c.text, fontFamily: 'Outfit')),
              ),
              PopupMenuItem(
                value: 'pinned',
                child: Text('Pinned Messages',
                    style: TextStyle(
                        color: c.text, fontFamily: 'Outfit')),
              ),
              PopupMenuItem(
                value: 'mute',
                child: Text(
                    _isMuted
                        ? 'Unmute Notifications'
                        : 'Mute Notifications',
                    style: TextStyle(
                        color: c.text, fontFamily: 'Outfit')),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text(
                    _isBlocked ? 'Unblock' : 'Block',
                    style: TextStyle(
                        color: c.error,
                        fontFamily: 'Outfit')),
              ),
              PopupMenuItem(
                value: 'delete_chat',
                child: Text('Delete Chat',
                    style: TextStyle(
                        color: c.error,
                        fontFamily: 'Outfit')),
              ),
            ],
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              c.background.computeLuminance() > 0.5
                  ? Brightness.dark
                  : Brightness.light,
        ),
      ),
      body: Column(children: [
        // Message list
        Expanded(
          child: _loading && _listItems.isEmpty
              ? Center(
                  child: CircularProgressIndicator(
                      color: c.primary))
              : _listItems.isEmpty
                  ? _EmptyConversation(c: c)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _listItems.length +
                          (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == 0 && _loadingMore) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: c.primary)),
                            ),
                          );
                        }
                        final idx =
                            _loadingMore ? i - 1 : i;
                        final item = _listItems[idx];
                        if (item.isDivider) {
                          return DateDivider(date: item.date!);
                        }
                        final msg = item.message!;
                        return MessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          isMyMessage:
                              msg.senderId == uid,
                          onLongPress: () =>
                              _onMessageLongPress(msg),
                          onReactionTap: (emoji) {
                            ref
                                .read(chatProvider.notifier)
                                .toggleReaction(
                                    msg.id,
                                    emoji,
                                    uid);
                          },
                          onTapImage: () {
                            // Open full-screen image viewer
                          },
                        );
                      },
                    ),
        ),
        // Input bar
        ChatInputBar(
          controller: _inputCtrl,
          conversationId: widget.chatId,
          currentUserId: uid,
          otherUserName: partnerName,
          otherUser: _chatPartner,
          isBlocked: _isBlocked,
          theyBlockedMe: _theyBlockedMe,
          privacyBlocked: _privacyBlocked,
          privacyMessage: _privacyMessage,
          isIncomingRequest: _isIncomingRequest,
          isOutgoingRequest: _isOutgoingRequest,
          sentMessageCount: _sentMessageCount,
          isRecordingVoice: _isRecordingVoice,
          uploadingMedia: _uploadingMedia,
          onSend: _handleSend,
          startTyping: (convId) => ref
              .read(chatProvider.notifier)
              .startTyping(convId),
          stopTyping: (convId) => ref
              .read(chatProvider.notifier)
              .stopTyping(convId),
          onPickAndSendImage: _pickAndSendImage,
          onStartVoiceRecording: () {
            // Voice recording handled separately
          },
          onAcceptRequest: _acceptRequest,
          onDeleteRequest: _deleteRequest,
          onBlockUnblock: _toggleBlock,
        ),
      ]),
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'view_profile':
        final id =
            (_chatPartner?['id'] ?? '').toString();
        if (id.isNotEmpty) context.push('/profile/$id');
        break;
      case 'pinned':
        context.push('/chat/pinned/${widget.chatId}');
        break;
      case 'mute':
        _toggleMute();
        break;
      case 'block':
        _toggleBlock();
        break;
      case 'delete_chat':
        _confirmDeleteChat();
        break;
    }
  }

  void _toggleMute() async {
    final uid = _currentUserId;
    final partner = _chatPartner;
    if (uid == null || partner == null) return;

    try {
      if (_isMuted) {
        await mutedChatsService.unmuteChat(
            userId: uid,
            mutedUserId: partner['id'].toString());
        if (mounted) setState(() => _isMuted = false);
      } else {
        // Show mute duration picker
        _showMuteDurationPicker(uid, partner['id'].toString());
      }
    } catch (_) {}
  }

  void _showMuteDurationPicker(
      String userId, String mutedUserId) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text('Mute Notifications',
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: c.text)),
        const SizedBox(height: 8),
        ...['8_hours', '1_week', 'always'].map((d) {
          final label = d == '8_hours'
              ? '8 hours'
              : d == '1_week'
                  ? '1 week'
                  : 'Always';
          return ListTile(
            title: Text(label,
                style: TextStyle(
                    color: c.text, fontFamily: 'Outfit')),
            onTap: () async {
              Navigator.pop(context);
              await mutedChatsService.muteChat(
                userId: userId,
                mutedUserId: mutedUserId,
                conversationId: widget.chatId,
                muteDuration: d,
              );
              if (mounted) setState(() => _isMuted = true);
            },
          );
        }),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }

  void _confirmDeleteChat() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete Chat?',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        content: Text('This will delete the conversation for you only.',
            style: TextStyle(
                color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(chatProvider.notifier)
                  .deleteConversation(widget.chatId);
              context.pop();
            },
            child: Text('Delete',
                style: TextStyle(
                    color: c.error,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── List Item union type ──────────────────────────────────────────────────────
class _ListItem {
  final bool isDivider;
  final ChatMessage? message;
  final DateTime? date;

  const _ListItem._({required this.isDivider, this.message, this.date});

  factory _ListItem.message(ChatMessage m) =>
      _ListItem._(isDivider: false, message: m);
  factory _ListItem.dateDivider(DateTime d) =>
      _ListItem._(isDivider: true, date: d);
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyConversation extends StatelessWidget {
  final ThemeColors c;
  const _EmptyConversation({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.chat_bubble_outline, size: 64, color: c.textTertiary),
        const SizedBox(height: 12),
        Text('Start a conversation',
            style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Send a message to get started',
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                fontFamily: 'Outfit')),
      ]),
    );
  }
}

// Expose chatApiService singleton
final chatApiService = ChatApiService();

// Upload service placeholder
class UploadService {
  Future<Map<String, dynamic>> uploadFile(File file, String type) async {
    try {
      final formData = {
        'type': type,
        'file': file.path,
      };
      // Use the actual upload service
      final res = await dioClient.post(
        AppEndpoints.filesUploadUrl,
        data: formData,
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }
}
