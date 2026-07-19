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
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_actions_bottom_sheet.dart';
import '../../widgets/chat/message_reactions.dart';
import '../../widgets/common/verification_badge.dart';

// Module-level group details cache — avoids "Updating..." flash on re-open
final _groupDetailsCache = <String, Map<String, dynamic>>{};
final _groupSyncTimestamps = <String, int>{};
const _syncStaleMs = 5 * 60 * 1000;

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatScreen> createState() =>
      _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with WidgetsBindingObserver {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = ChatInputBarController();
  final _imagePicker = ImagePicker();

  Map<String, dynamic>? _groupInfo;
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _permissions;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 50;

  bool _isAdmin = false;
  bool _isOwner = false;
  bool _isMember = true;
  bool _isMuted = false;
  bool _uploadingMedia = false;
  bool _topicsEnabled = false;

  List<_ListItem> _listItems = [];
  String? _currentUserId;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(chatProvider.notifier)
          .setActiveConversation(widget.groupId);
      ref
          .read(chatProvider.notifier)
          .markAsRead(widget.groupId);
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

    // Join group room
    ref.read(chatProvider.notifier).joinGroup(widget.groupId);
    ref.read(chatProvider.notifier).setActiveConversation(widget.groupId);

    // Serve from cache immediately
    final cached = _groupDetailsCache[widget.groupId];
    if (cached != null) {
      setState(() {
        _groupInfo = cached;
        _topicsEnabled = cached['topics_enabled'] == true;
        _loading = false;
      });
    }

    // Serve messages from store immediately
    final stored =
        ref.read(conversationMessagesProvider(widget.groupId));
    if (stored.isNotEmpty) {
      _buildListItems(stored);
      setState(() => _loading = false);
    }

    // Parallel: load details + messages
    await Future.wait([
      _loadGroupDetails(uid),
      _loadMessages(reset: true),
    ]);

    ref.read(chatProvider.notifier).markAsRead(widget.groupId);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadGroupDetails(String uid) async {
    try {
      final data = await chatApiService.getGroupDetail(widget.groupId);
      if (data == null) return;

      _groupDetailsCache[widget.groupId] = data;

      final membersList = data['members'] as List? ?? [];
      _members =
          membersList.map((m) => Map<String, dynamic>.from(m as Map)).toList();

      final me = _members.firstWhere(
          (m) => m['user_id']?.toString() == uid || m['id']?.toString() == uid,
          orElse: () => {});
      _isAdmin = me['role'] == 'admin' || me['role'] == 'moderator';
      _isOwner = me['role'] == 'owner' || data['owner_id']?.toString() == uid;
      _isMember = me.isNotEmpty;

      final perms = await chatApiService.getGroupPermissions(widget.groupId);

      if (mounted) {
        setState(() {
          _groupInfo = data;
          _permissions = perms;
          _topicsEnabled = data['topics_enabled'] == true;
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
      final msgs = await chatApiService.getGroupMessages(
        widget.groupId,
        limit: _pageSize,
        offset: _offset,
      );

      final chatMsgs = msgs
          .map((m) => _normalizeGroupMessage(m))
          .toList()
          .reversed
          .toList();

      if (reset) {
        ref
            .read(chatProvider.notifier)
            .setMessages(widget.groupId, chatMsgs);
      } else {
        ref
            .read(chatProvider.notifier)
            .appendOlderMessages(widget.groupId, chatMsgs);
      }

      _offset += msgs.length;
      _hasMore = msgs.length >= _pageSize;
    } catch (_) {}

    if (mounted) setState(() => _loadingMore = false);
  }

  ChatMessage _normalizeGroupMessage(Map<String, dynamic> m) {
    // Group messages have sender info nested
    final sender = m['sender'] as Map<String, dynamic>? ?? {};
    return ChatMessage.fromJson({
      ...m,
      'conversation_id': widget.groupId,
      'sender_name': sender['name'] ?? sender['username'] ?? m['sender_name'] ?? '',
      'sender_pic': sender['profile_pic'] ?? m['sender_pic'],
      'sender_username': sender['username'],
      'is_verified': sender['is_verified'] ?? false,
      'verification_badge': sender['verification_badge'],
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <=
            _scrollCtrl.position.minScrollExtent + 200 &&
        _hasMore &&
        !_loadingMore) {
      _loadMessages();
    }
  }

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

  Future<void> _handleSend() async {
    final text = _inputCtrl.text.trim();
    final editing = _inputCtrl.editingMessage;
    final replyTo = _inputCtrl.replyingTo;
    final uid = _currentUserId;
    if (uid == null) return;

    if (text.isEmpty) return;

    if (editing != null) {
      _inputCtrl.clearEditing();
      try {
        await chatApiService.editGroupMessage(editing.id, text);
      } catch (_) {}
      return;
    }

    _inputCtrl.clear();
    ref.read(chatProvider.notifier).stopTyping(widget.groupId);

    await ref.read(chatProvider.notifier).sendGroupMessage(
          groupId: widget.groupId,
          content: text,
          messageType: 'text',
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
  }

  Future<String?> _pickAndSendImage() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return null;

    setState(() => _uploadingMedia = true);
    try {
      final uploadSvc = UploadService();
      final result =
          await uploadSvc.uploadFile(File(picked.path), 'image');
      final url = result['url'] as String?;
      if (url == null) return null;

      final imageFile = File(picked.path);
      final decodedImage = await decodeImageFromList(
          await imageFile.readAsBytes());
      final mediaData = {
        'width': decodedImage.width,
        'height': decodedImage.height,
      };

      await ref.read(chatProvider.notifier).sendGroupMessage(
            groupId: widget.groupId,
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

  void _onMessageLongPress(ChatMessage message) {
    final uid = _currentUserId;
    final isMyMessage = message.senderId == uid;
    final canDelete = isMyMessage || _isAdmin || _isOwner;

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
                final username = uid ?? '';
                ref
                    .read(chatProvider.notifier)
                    .toggleReaction(message.id, emoji, username);
              },
            ),
          ),
          MessageActionsBottomSheet(
            message: message,
            isMyMessage: isMyMessage,
            isAdmin: _isAdmin || _isOwner,
            isPinned: message.isPinned,
            canDeleteForEveryone: canDelete,
            onAction: (action) =>
                _handleMessageAction(action, message),
          ),
        ],
      ),
    );
  }

  void _handleMessageAction(MessageAction action, ChatMessage msg) {
    final uid = _currentUserId;
    switch (action) {
      case MessageAction.reply:
        _inputCtrl.setReplyTo(msg);
        _inputCtrl.focus();
        break;
      case MessageAction.edit:
        _inputCtrl.setEditing(msg);
        break;
      case MessageAction.delete:
        _confirmDelete(msg, false);
        break;
      case MessageAction.deleteForEveryone:
        _confirmDelete(msg, true);
        break;
      case MessageAction.pin:
        _pinMessage(msg, true);
        break;
      case MessageAction.unpin:
        _pinMessage(msg, false);
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
            forEveryone ? 'Delete for everyone?' : 'Delete for yourself?',
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
            onPressed: () async {
              Navigator.pop(ctx);
              if (forEveryone) {
                try {
                  await chatApiService.deleteGroupMessageRest(
                      message.id,
                      forEveryone ? 'for_everyone' : 'for_me');
                } catch (_) {}
              }
              ref
                  .read(chatProvider.notifier)
                  .deleteGroupMessage(
                      widget.groupId, message.id,
                      deleteType: forEveryone
                          ? 'for_everyone'
                          : 'for_me');
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
        await chatApiService.pinGroupMessage(
            widget.groupId, message.id);
      } else {
        await chatApiService.unpinGroupMessage(
            widget.groupId, message.id);
      }
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = _currentUserId ?? '';

    final messages =
        ref.watch(conversationMessagesProvider(widget.groupId));
    _buildListItems(messages);

    final typingUsers =
        ref.watch(conversationTypingProvider(widget.groupId));

    final name = _groupInfo?['name'] ?? 'Group';
    final pic = _groupInfo?['image'] ?? _groupInfo?['avatar'];
    final memberCount =
        _groupInfo?['member_count'] ?? _members.length;
    final isLive = _groupInfo?['is_live'] == true;

    final typingNames = typingUsers
        .where((id) => id != uid)
        .map((id) {
          final member = _members.firstWhere(
              (m) => m['user_id']?.toString() == id || m['id']?.toString() == id,
              orElse: () => {});
          return (member['name'] ?? member['username'] ?? 'Someone')
              .toString();
        })
        .take(2)
        .join(', ');
    final isTyping = typingNames.isNotEmpty;

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
          onTap: () =>
              context.push('/chat/group-info/${widget.groupId}'),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.surface,
                backgroundImage:
                    pic != null ? CachedNetworkImageProvider(pic) : null,
                child: pic == null
                    ? Text(
                        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                        style: TextStyle(
                            color: c.text,
                            fontSize: 13,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600))
                    : null,
              ),
              if (isLive)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isTyping
                        ? '$typingNames typing...'
                        : '$memberCount members',
                    style: TextStyle(
                      color: isTyping ? c.primary : c.textSecondary,
                      fontSize: 11,
                      fontFamily: 'Outfit',
                      fontStyle: isTyping
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
        actions: [
          if (_topicsEnabled)
            IconButton(
              icon: Icon(Icons.topic, color: c.text),
              onPressed: () =>
                  context.push('/chat/group-topics/${widget.groupId}'),
            ),
          IconButton(
            icon: Icon(Icons.info_outline, color: c.text),
            onPressed: () =>
                context.push('/chat/group-info/${widget.groupId}'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: c.text),
            color: c.surface,
            onSelected: _onMenuAction,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'search',
                child: Text('Search',
                    style: TextStyle(
                        color: c.text, fontFamily: 'Outfit')),
              ),
              PopupMenuItem(
                value: 'pinned',
                child: Text('Pinned Messages',
                    style: TextStyle(
                        color: c.text, fontFamily: 'Outfit')),
              ),
              if (_isAdmin || _isOwner) ...[
                PopupMenuItem(
                  value: 'permissions',
                  child: Text('Permissions',
                      style: TextStyle(
                          color: c.text, fontFamily: 'Outfit')),
                ),
                PopupMenuItem(
                  value: 'action_log',
                  child: Text('Action Log',
                      style: TextStyle(
                          color: c.text, fontFamily: 'Outfit')),
                ),
              ],
              PopupMenuItem(
                value: 'leave',
                child: Text('Leave Group',
                    style: TextStyle(
                        color: c.error, fontFamily: 'Outfit')),
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
        Expanded(
          child: _loading && _listItems.isEmpty
              ? Center(
                  child: CircularProgressIndicator(color: c.primary))
              : _listItems.isEmpty
                  ? _EmptyGroup(c: c, groupName: name)
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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: c.primary)),
                            ),
                          );
                        }
                        final idx = _loadingMore ? i - 1 : i;
                        final item = _listItems[idx];
                        if (item.isDivider) {
                          return DateDivider(date: item.date!);
                        }
                        final msg = item.message!;
                        return MessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          isMyMessage: msg.senderId == uid,
                          showAvatar: msg.senderId != uid,
                          senderName: msg.senderName,
                          onLongPress: () =>
                              _onMessageLongPress(msg),
                          onReactionTap: (emoji) {
                            ref
                                .read(chatProvider.notifier)
                                .toggleReaction(msg.id, emoji, uid);
                          },
                        );
                      },
                    ),
        ),
        ChatInputBar(
          controller: _inputCtrl,
          conversationId: widget.groupId,
          currentUserId: uid,
          isGroup: true,
          groupInfo: _groupInfo,
          uploadingMedia: _uploadingMedia,
          onSend: _handleSend,
          startTyping: (id) =>
              ref.read(chatProvider.notifier).startTyping(id),
          stopTyping: (id) =>
              ref.read(chatProvider.notifier).stopTyping(id),
          onPickAndSendImage: _pickAndSendImage,
          onStartVoiceRecording: () {},
        ),
      ]),
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'pinned':
        context
            .push('/chat/group-pinned/${widget.groupId}');
        break;
      case 'permissions':
        context
            .push('/chat/group-permissions/${widget.groupId}');
        break;
      case 'action_log':
        context.push(
            '/chat/group-action-log/${widget.groupId}');
        break;
      case 'leave':
        _confirmLeave();
        break;
    }
  }

  void _confirmLeave() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Leave Group?',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        content: Text('You will no longer receive messages from this group.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await chatApiService.leaveGroup(widget.groupId);
                if (mounted) context.pop();
              } catch (_) {}
            },
            child: Text('Leave',
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

class _EmptyGroup extends StatelessWidget {
  final ThemeColors c;
  final String groupName;
  const _EmptyGroup({required this.c, required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.group_outlined, size: 64, color: c.textTertiary),
        const SizedBox(height: 12),
        Text('Welcome to $groupName!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Be the first to send a message',
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                fontFamily: 'Outfit')),
      ]),
    );
  }
}

// Expose service singleton
final chatApiService = ChatApiService();

class UploadService {
  Future<Map<String, dynamic>> uploadFile(File file, String type) async {
    final res = await dioClient.post(
      AppEndpoints.filesUploadUrl,
      data: {'type': type, 'file': file.path},
    );
    return res.data as Map<String, dynamic>;
  }
}
