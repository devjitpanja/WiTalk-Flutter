import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';
import '../../services/muted_chats_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_actions_bottom_sheet.dart';
import '../../widgets/chat/quick_emoji_picker.dart';
import '../../widgets/common/verification_badge.dart';

// ── Module-level cache — persists across mounts like RN conversationSyncTimestamps
final _conversationSyncTimestamps = <String, int>{};
const _syncStaleMs = 5 * 60 * 1000; // 5 minutes

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final Map<String, dynamic>? otherUser;
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = ChatInputBarController();
  final _imagePicker = ImagePicker();

  Map<String, dynamic>? _chatPartner;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 30; // match RN limit=30

  bool _uploadingMedia = false;
  bool _isMuted = false;
  bool _isBlocked = false;
  bool _theyBlockedMe = false;
  bool _privacyBlocked = false;
  String? _privacyMessage;
  bool _isIncomingRequest = false;
  bool _isOutgoingRequest = false;
  int _sentMessageCount = 0;

  String? _currentUserId;

  // Scroll-to-bottom button
  bool _showScrollToBottom = false;
  bool _isAtBottom = true;

  // Typing indicator dots animation
  late AnimationController _dot0Ctrl;
  late AnimationController _dot1Ctrl;
  late AnimationController _dot2Ctrl;
  late Animation<double> _dot0Anim;
  late Animation<double> _dot1Anim;
  late Animation<double> _dot2Anim;

  List<_ListItem> _listItems = [];
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _initTypingDotAnimations();
    // Defer until after the first frame so StateNotifier.state= is not called
    // during the widget-mount phase (state_notifier throws on that).
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _initTypingDotAnimations() {
    _dot0Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1240));
    _dot1Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1240));
    _dot2Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1240));
    _dot0Anim = _buildDotAnim(_dot0Ctrl);
    _dot1Anim = _buildDotAnim(_dot1Ctrl);
    _dot2Anim = _buildDotAnim(_dot2Ctrl);
  }

  Animation<double> _buildDotAnim(AnimationController ctrl) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 22.6),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 22.6),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 54.8),
    ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
  }

  void _startTypingAnimation() {
    if (_dot0Ctrl.isAnimating) return;
    _dot0Ctrl.repeat();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) _dot1Ctrl.repeat();
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _dot2Ctrl.repeat();
    });
  }

  void _stopTypingAnimation() {
    _dot0Ctrl.stop();
    _dot1Ctrl.stop();
    _dot2Ctrl.stop();
    _dot0Ctrl.reset();
    _dot1Ctrl.reset();
    _dot2Ctrl.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _dot0Ctrl.dispose();
    _dot1Ctrl.dispose();
    _dot2Ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(chatProvider.notifier).setActiveConversation(widget.chatId);
      ref.read(chatProvider.notifier).markAsRead(widget.chatId);
    } else if (state == AppLifecycleState.paused) {
      ref.read(chatProvider.notifier).setActiveConversation(null);
    }
  }

  Future<void> _init() async {
    final uid = ref.read(authProvider).uid;
    _currentUserId = uid;

    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    ref.read(chatProvider.notifier).joinConversation(widget.chatId);
    ref.read(chatProvider.notifier).setActiveConversation(widget.chatId);

    // Load from in-memory store first (instant)
    final stored = ref.read(conversationMessagesProvider(widget.chatId));
    if (stored.isNotEmpty) {
      _buildListItems(stored);
      _lastMessageCount = stored.length;
      if (mounted) setState(() => _loading = false);
    }

    // Sync from server if stale
    final lastSync = _conversationSyncTimestamps[widget.chatId];
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale = lastSync == null || now - lastSync > _syncStaleMs;

    if (isStale) {
      await _loadMessages(reset: true);
      _conversationSyncTimestamps[widget.chatId] = now;
    } else {
      if (mounted) setState(() => _loading = false);
    }

    if (widget.otherUser == null) {
      await _loadConversationDetail();
    } else {
      _chatPartner = widget.otherUser;
    }

    ref.read(chatProvider.notifier).markAsRead(widget.chatId);

    final otherUserId =
        (_chatPartner?['id'] ?? widget.otherUser?['id'])?.toString();

    // Run mute + block checks in parallel
    await Future.wait([
      _loadMuteStatus(uid, otherUserId),
      _checkBlockStatus(uid, otherUserId),
    ]);

    if (mounted) {
      setState(() => _loading = false);
      _scrollToBottom(animated: false);
    }
  }

  Future<void> _loadMuteStatus(String uid, String? otherUserId) async {
    if (otherUserId == null) return;
    try {
      final mutedChats = await mutedChatsService.getUserMutedChats(uid);
      if (mounted) {
        setState(() {
          _isMuted = mutedChats
              .any((m) => m['mutedUserId'].toString() == otherUserId);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadConversationDetail() async {
    try {
      final data = await chatApiService.getConversation(widget.chatId);
      if (data != null && mounted) {
        setState(() {
          _chatPartner = data['other_user'] as Map<String, dynamic>? ?? data;
          _isIncomingRequest = data['status'] == 'request_pending' &&
              data['initiator_id'].toString() != _currentUserId;
          _isOutgoingRequest = data['status'] == 'request_pending' &&
              data['initiator_id'].toString() == _currentUserId;
          _sentMessageCount =
              (data['sent_message_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkBlockStatus(String uid, String? otherUserId) async {
    if (otherUserId == null) return;
    try {
      final res =
          await dioClient.get('${AppEndpoints.checkBlock}/$uid/$otherUserId');
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
      if (mounted && !_loading) setState(() => _loadingMore = true);
    } else {
      if (mounted) setState(() => _loadingMore = true);
    }

    try {
      final msgs = await chatApiService.getMessages(
        widget.chatId,
        limit: _pageSize,
        offset: _offset,
        userId: uid,
      );

      if (!mounted) return;

      // API returns newest-first; reverse so oldest is first in list (newest at bottom)
      final chatMsgs = msgs
          .map((m) => ChatMessage.fromJson(m))
          .toList()
          .reversed
          .toList();

      if (reset) {
        ref.read(chatProvider.notifier).setMessages(widget.chatId, chatMsgs);
      } else {
        ref
            .read(chatProvider.notifier)
            .appendOlderMessages(widget.chatId, chatMsgs);
      }

      _offset += msgs.length;
      _hasMore = msgs.length >= _pageSize;
    } catch (e) {
      debugPrint('[ChatConversation] _loadMessages error: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;

    // Load older messages when near top
    if (_scrollCtrl.position.pixels <=
            _scrollCtrl.position.minScrollExtent + 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadMessages();
    }

    // Scroll-to-bottom button
    final distanceFromBottom =
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels;
    final atBottom = distanceFromBottom <= 100;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        _showScrollToBottom = !atBottom;
      });
    }
  }

  void _buildListItems(List<ChatMessage> msgs) {
    final items = <_ListItem>[];
    DateTime? lastDate;

    for (final msg in msgs) {
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

  // ── Profile bottom sheet — mirrors RN BottomSheet with user options ──────────
  void _openProfileSheet() {
    final c = context.colors;
    final partner = _chatPartner ?? widget.otherUser;
    if (partner == null) return;

    final partnerName = (partner['name'] ?? partner['username'] ?? 'User') as String;
    final partnerUsername = (partner['username'] ?? '') as String;
    final partnerPic = partner['profile_pic'] as String?;
    final isVerified = partner['is_verified'] == true;
    final verificationBadge = partner['verification_badge'];

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // User info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: c.background,
                  backgroundImage: partnerPic != null
                      ? CachedNetworkImageProvider(partnerPic)
                      : null,
                  child: partnerPic == null
                      ? Text(
                          (partnerName.isNotEmpty ? partnerName[0] : '?')
                              .toUpperCase(),
                          style: TextStyle(
                              color: c.text,
                              fontSize: 18,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          partnerName,
                          style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: c.text),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          VerificationBadge(
                              isVerified: true,
                              badge: verificationBadge,
                              size: 16),
                        ],
                      ]),
                      if (partnerUsername.isNotEmpty)
                        Text(
                          '@$partnerUsername',
                          style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: c.border),

            // Options
            _SheetOption(
              icon: Icons.person_outline,
              label: 'View Profile',
              c: c,
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 250), () {
                  final id = partner['id']?.toString() ?? '';
                  if (id.isNotEmpty) context.push('/profile/$id');
                });
              },
            ),
            _SheetOption(
              icon: Icons.delete_sweep_outlined,
              label: 'Clear Chat',
              c: c,
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 250),
                    () => _confirmClearChat());
              },
            ),
            _SheetOption(
              icon: _isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              label: _isMuted ? 'Unmute' : 'Mute',
              c: c,
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 250),
                    () => _toggleMute());
              },
            ),
            _SheetOption(
              icon: _isBlocked ? Icons.check_circle_outline : Icons.block,
              label: _isBlocked ? 'Unblock' : 'Block',
              c: c,
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 250),
                    () => _toggleBlock());
              },
            ),
            _SheetOption(
              icon: Icons.flag_outlined,
              label: 'Report',
              c: c,
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                // TODO: navigate to Report screen
              },
            ),
            _SheetOption(
              icon: Icons.delete_forever_outlined,
              label: 'Delete Chat',
              c: c,
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 250),
                    () => _confirmDeleteChat());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Send message ─────────────────────────────────────────────────────────────
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
      _inputCtrl.clearEditing();
      try {
        await chatApiService.editMessage(
          messageId: editing.id,
          userId: uid,
          newContent: text,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to edit message')));
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
    if (_isOutgoingRequest) setState(() => _sentMessageCount++);
  }

  Future<String?> _pickAndSendImage() async {
    final partner = _chatPartner;
    final uid = _currentUserId;
    if (partner == null || uid == null) return null;

    final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return null;

    setState(() => _uploadingMedia = true);
    try {
      final result =
          await UploadService().uploadFile(File(picked.path), 'image');
      final url = result['url'] as String?;
      if (url == null) return null;

      final imageFile = File(picked.path);
      final decodedImage =
          await decodeImageFromList(await imageFile.readAsBytes());

      await ref.read(chatProvider.notifier).sendMessage(
            conversationId: widget.chatId,
            receiverId: partner['id'].toString(),
            content: '',
            messageType: 'image',
            mediaUrl: url,
            mediaData: {
              'width': decodedImage.width,
              'height': decodedImage.height,
            },
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
      if (mounted) setState(() {
        _isIncomingRequest = false;
        _isOutgoingRequest = false;
      });
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
        if (mounted) setState(() => _isBlocked = false);
      } else {
        await dioClient.post(AppEndpoints.blockUser,
            data: {'userId': uid, 'blockedUserId': partner['id']});
        if (mounted) setState(() => _isBlocked = true);
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: QuickEmojiPicker(
              onSelect: (emoji) {
                Navigator.pop(context);
                ref
                    .read(chatProvider.notifier)
                    .toggleReaction(
                        message.id, emoji, _currentUserId ?? '');
              },
              onMore: () => Navigator.pop(context),
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
            style:
                TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
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
              ref.read(chatProvider.notifier).deleteMessage(message.id,
                  deleteType: forEveryone ? 'for_everyone' : 'for_me');
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
    // TODO: show LanguageSelectorSheet → chatApiService.translateMessage
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDarkMode = ref.watch(themeProvider);
    final uid = _currentUserId ?? '';

    final messages = ref.watch(conversationMessagesProvider(widget.chatId));

    // Auto-scroll when new messages arrive and user is at bottom
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      if (_isAtBottom) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    }

    _buildListItems(messages);

    final typingUsers =
        ref.watch(conversationTypingProvider(widget.chatId));
    final isPartnerOnline = ref.watch(
        userOnlineProvider((_chatPartner?['id'] ?? '').toString()));

    final partnerName = _chatPartner?['name'] ??
        _chatPartner?['username'] ??
        widget.otherUser?['name'] ??
        widget.otherUser?['username'] ??
        'Chat';
    final partnerPic =
        _chatPartner?['profile_pic'] ?? widget.otherUser?['profile_pic'];
    final isVerified = _chatPartner?['is_verified'] == true ||
        widget.otherUser?['is_verified'] == true;
    final verificationBadge = _chatPartner?['verification_badge'] ??
        widget.otherUser?['verification_badge'];

    final isTyping = typingUsers.isNotEmpty && !typingUsers.contains(uid);

    if (isTyping) {
      _startTypingAnimation();
    } else if (_dot0Ctrl.isAnimating) {
      _stopTypingAnimation();
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        // RN: backgroundColor: theme.surface
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        // Tapping the header opens the profile bottom sheet (same as RN)
        title: GestureDetector(
          onTap: _openProfileSheet,
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.background,
                backgroundImage: partnerPic != null
                    ? CachedNetworkImageProvider(partnerPic as String)
                    : null,
                child: partnerPic == null
                    ? Text(
                        (partnerName.toString().isNotEmpty
                                ? partnerName.toString()[0]
                                : '?')
                            .toUpperCase(),
                        style: TextStyle(
                            color: c.text,
                            fontSize: 14,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600))
                    : null,
              ),
              if (isPartnerOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    partnerName.toString(),
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 3),
                    VerificationBadge(
                        isVerified: true,
                        badge: verificationBadge,
                        size: 14),
                  ],
                ]),
                Text(
                  isTyping
                      ? 'typing...'
                      : isPartnerOnline
                          ? 'Online'
                          : 'Offline',
                  style: TextStyle(
                    color: isTyping ? c.primary : c.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontStyle:
                        isTyping ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ]),
        ),
        // Only three-dot menu (no call/video — not in RN ChatConversation)
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: c.text),
            onPressed: _openProfileSheet,
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: c.surface.computeLuminance() > 0.5
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            // Chat background image
            Positioned.fill(
              child: Image.asset(
                isDarkMode
                    ? 'assets/images/chatbg.jpeg'
                    : 'assets/images/LightchatBg.jpeg',
                fit: BoxFit.cover,
                opacity: AlwaysStoppedAnimation(isDarkMode ? 0.15 : 1.0),
              ),
            ),

            // Encryption notice + messages
            _loading && _listItems.isEmpty
                ? Center(
                    child:
                        CircularProgressIndicator(color: c.primary))
                : _listItems.isEmpty
                    ? _EmptyConversation(c: c)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _listItems.length +
                            (_loadingMore ? 1 : 0) +
                            1, // +1 for encryption notice at top
                        itemBuilder: (ctx, i) {
                          // Encryption notice at top (like RN ListHeaderComponent)
                          if (i == 0) {
                            if (_loadingMore) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: c.primary)),
                                ),
                              );
                            }
                            return _EncryptionNotice(c: c);
                          }
                          final idx = i - 1; // offset for header
                          final item = _listItems[idx];
                          if (item.isDivider) {
                            return DateDivider(date: item.date!);
                          }
                          final msg = item.message!;
                          return MessageBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            isMyMessage: msg.senderId == uid,
                            onLongPress: () =>
                                _onMessageLongPress(msg),
                            onReplySwipe: (m) {
                              _inputCtrl.setReplyTo(m);
                              _inputCtrl.focus();
                            },
                            onReactionTap: (emoji) {
                              ref
                                  .read(chatProvider.notifier)
                                  .toggleReaction(msg.id, emoji, uid);
                            },
                            onTapImage: () {},
                          );
                        },
                      ),

            // Typing indicator (3-dot bounce)
            if (isTyping)
              Positioned(
                left: 16,
                bottom: 8,
                child: _TypingBubble(
                  dot0: _dot0Anim,
                  dot1: _dot1Anim,
                  dot2: _dot2Anim,
                  c: c,
                ),
              ),

            // Scroll-to-bottom button (same position as RN — relative bottom)
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: 12,
                child: GestureDetector(
                  onTap: _scrollToBottom,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDarkMode ? 0.4 : 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: c.text, size: 22),
                  ),
                ),
              ),
          ]),
        ),

        // Input bar
        ChatInputBar(
          controller: _inputCtrl,
          conversationId: widget.chatId,
          currentUserId: uid,
          otherUserName: partnerName.toString(),
          otherUser: _chatPartner,
          isBlocked: _isBlocked,
          theyBlockedMe: _theyBlockedMe,
          privacyBlocked: _privacyBlocked,
          privacyMessage: _privacyMessage,
          isIncomingRequest: _isIncomingRequest,
          isOutgoingRequest: _isOutgoingRequest,
          sentMessageCount: _sentMessageCount,
          isRecordingVoice: false,
          uploadingMedia: _uploadingMedia,
          onSend: _handleSend,
          startTyping: (convId) =>
              ref.read(chatProvider.notifier).startTyping(convId),
          stopTyping: (convId) =>
              ref.read(chatProvider.notifier).stopTyping(convId),
          onPickAndSendImage: _pickAndSendImage,
          onStartVoiceRecording: () {},
          onAcceptRequest: _acceptRequest,
          onDeleteRequest: _deleteRequest,
          onBlockUnblock: _toggleBlock,
        ),
      ]),
    );
  }

  void _toggleMute() async {
    final uid = _currentUserId;
    final partner = _chatPartner;
    if (uid == null || partner == null) return;
    try {
      if (_isMuted) {
        await mutedChatsService.unmuteChat(
            userId: uid, mutedUserId: partner['id'].toString());
        if (mounted) setState(() => _isMuted = false);
      } else {
        _showMuteDurationPicker(uid, partner['id'].toString());
      }
    } catch (_) {}
  }

  void _showMuteDurationPicker(String userId, String mutedUserId) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                style: TextStyle(color: c.text, fontFamily: 'Outfit')),
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

  void _confirmClearChat() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Clear Chat?',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        content: Text('All messages will be cleared for you only.',
            style:
                TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
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
              // TODO: call clear chat API endpoint
            },
            child: Text('Clear',
                style: TextStyle(
                    color: c.error,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
        content: Text(
            'This will delete the conversation for you only.',
            style:
                TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
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

// ── Profile sheet option row ──────────────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors c;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.c,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFFF3B30) : c.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDestructive
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                  : c.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Outfit',
                    color: color)),
          ),
          Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
        ]),
      ),
    );
  }
}

// ── Typing indicator bubble ───────────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  final Animation<double> dot0;
  final Animation<double> dot1;
  final Animation<double> dot2;
  final ThemeColors c;

  const _TypingBubble(
      {required this.dot0,
      required this.dot1,
      required this.dot2,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(anim: dot0, c: c),
        const SizedBox(width: 4),
        _Dot(anim: dot1, c: c),
        const SizedBox(width: 4),
        _Dot(anim: dot2, c: c),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final Animation<double> anim;
  final ThemeColors c;

  const _Dot({required this.anim, required this.c});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, anim.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c.textSecondary.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Encryption notice (RN ListHeaderComponent) ────────────────────────────────
class _EncryptionNotice extends StatelessWidget {
  final ThemeColors c;
  const _EncryptionNotice({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 12, color: c.textSecondary),
          const SizedBox(width: 4),
          Text(
            'All messages are encrypted and secured',
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'Outfit',
                color: c.textSecondary),
          ),
        ]),
      ),
    );
  }
}

// ── List Item union type ──────────────────────────────────────────────────────
class _ListItem {
  final bool isDivider;
  final ChatMessage? message;
  final DateTime? date;

  const _ListItem._(
      {required this.isDivider, this.message, this.date});

  factory _ListItem.message(ChatMessage m) =>
      _ListItem._(isDivider: false, message: m);
  factory _ListItem.dateDivider(DateTime d) =>
      _ListItem._(isDivider: true, date: d);
}

// ── Empty state ───────────────────────────────────────────────────────────────
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
