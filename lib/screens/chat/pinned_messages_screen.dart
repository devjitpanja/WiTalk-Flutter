import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _timeAgo(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final d = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  } catch (_) {
    return '';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PinnedMessagesScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final bool isGroup;
  final bool isAdmin;

  const PinnedMessagesScreen({
    super.key,
    required this.conversationId,
    required this.isGroup,
    this.isAdmin = false,
  });

  @override
  ConsumerState<PinnedMessagesScreen> createState() =>
      _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState
    extends ConsumerState<PinnedMessagesScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _page = 1;
  static const _pageSize = 20;

  final _scrollCtrl = ScrollController();
  String? _currentUserId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.isAdmin;
    _currentUserId = ref.read(authProvider).uid;
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _messages = [];
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      List<Map<String, dynamic>> items;
      if (widget.isGroup) {
        // Group pinned messages endpoint has pagination via query params
        final res = await dioClient.get(
          AppEndpoints.groupPinnedMessages(widget.conversationId),
          queryParameters: {'page': _page, 'limit': _pageSize},
        );
        final data = res.data['data'];
        if (data is List) {
          items = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['messages'] is List) {
          items = List<Map<String, dynamic>>.from(data['messages'] as List);
        } else {
          items = [];
        }
      } else {
        // Private chat pinned messages (no pagination on this endpoint,
        // returns all at once — serve paginated locally)
        if (_page == 1) {
          final all =
              await chatApiService.getPinnedMessages(widget.conversationId);
          // Store all; slice for page
          _messages = [];
          items = all.take(_pageSize).toList();
          _hasMore = all.length > _pageSize;
          // Cache rest for subsequent "pages"
          _allPrivatePinned = all;
        } else {
          final start = (_page - 1) * _pageSize;
          final end = (start + _pageSize).clamp(0, _allPrivatePinned.length);
          items = _allPrivatePinned.sublist(start, end);
          _hasMore = end < _allPrivatePinned.length;
        }
      }

      if (mounted) {
        setState(() {
          _messages = reset ? items : [..._messages, ...items];
          _hasMore = widget.isGroup
              ? items.length >= _pageSize
              : _hasMore;
          _page++;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _loadingMore = false; });
      }
    }
  }

  // Cache for private chat pinned messages (loaded once, paginated locally)
  List<Map<String, dynamic>> _allPrivatePinned = [];

  Future<void> _unpin(Map<String, dynamic> msg) async {
    final msgId = msg['id']?.toString() ?? '';
    if (msgId.isEmpty) return;

    final confirmed = await _confirmDialog(
      context: context,
      title: 'Unpin Message',
      body: 'Remove this message from pinned?',
      confirmLabel: 'Unpin',
    );
    if (!confirmed) return;

    try {
      if (widget.isGroup) {
        await chatApiService.unpinGroupMessage(
            widget.conversationId, msgId);
      } else {
        await chatApiService.unpinMessage(widget.conversationId, msgId);
      }
      if (mounted) {
        setState(() =>
            _messages.removeWhere((m) => m['id']?.toString() == msgId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unpin message')));
      }
    }
  }

  void _jumpToMessage(Map<String, dynamic> msg) {
    // Pop back to the chat screen, passing the message id so it can scroll
    final msgId = msg['id']?.toString() ?? '';
    context.pop(msgId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
        title: Text(
          'Pinned Messages',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : CustomScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () => _load(reset: true),
                ),
                if (_messages.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_outlined,
                              size: 64, color: c.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'No pinned messages',
                            style: TextStyle(
                              color: c.text,
                              fontSize: 18,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Important messages you pin\nwill appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          if (i == _messages.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _PinnedMessageCard(
                            message: _messages[i],
                            currentUserId: _currentUserId,
                            isAdmin: _isAdmin,
                            onTap: () => _jumpToMessage(_messages[i]),
                            onUnpin: () => _unpin(_messages[i]),
                          );
                        },
                        childCount: _messages.length + (_loadingMore ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Pinned message card ───────────────────────────────────────────────────────

class _PinnedMessageCard extends StatelessWidget {
  final Map<String, dynamic> message;
  final String? currentUserId;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _PinnedMessageCard({
    required this.message,
    required this.currentUserId,
    required this.isAdmin,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sender = message['sender'] as Map<String, dynamic>? ??
        message['user'] as Map<String, dynamic>? ??
        {};
    final senderName = message['sender_name']?.toString() ??
        sender['name']?.toString() ??
        sender['username']?.toString() ??
        '';
    final senderPic = message['sender_pic']?.toString() ??
        sender['profile_pic']?.toString();
    final content = message['content']?.toString() ?? '';
    final msgType = message['message_type']?.toString() ??
        message['type']?.toString() ??
        'text';
    final pinnedAt = message['pinned_at']?.toString() ??
        message['created_at']?.toString();
    final senderId = message['sender_id']?.toString() ??
        sender['id']?.toString() ??
        sender['uid']?.toString() ??
        '';
    final canUnpin = isAdmin || senderId == currentUserId;

    String displayContent;
    switch (msgType) {
      case 'image':
        displayContent = 'Photo';
        break;
      case 'video':
        displayContent = 'Video';
        break;
      case 'audio':
        displayContent = 'Voice message';
        break;
      default:
        displayContent = content;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: c.border,
                  backgroundImage: senderPic != null
                      ? CachedNetworkImageProvider(senderPic)
                      : null,
                  child: senderPic == null
                      ? Text(
                          senderName.isNotEmpty
                              ? senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: c.text,
                              fontSize: 10,
                              fontFamily: 'Outfit'),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(pinnedAt),
                  style: TextStyle(
                    color: c.textTertiary,
                    fontFamily: 'Outfit',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content preview
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon for non-text
                if (msgType != 'text')
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 1),
                    child: Icon(
                      msgType == 'image'
                          ? Icons.image_outlined
                          : msgType == 'video'
                              ? Icons.videocam_outlined
                              : Icons.mic_outlined,
                      size: 16,
                      color: c.textTertiary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    displayContent,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Footer: Jump to + Unpin
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.push_pin, size: 13, color: c.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Pinned',
                      style: TextStyle(
                        color: c.primary,
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onTap,
                      child: Text(
                        'Jump to message',
                        style: TextStyle(
                          color: c.primary,
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (canUnpin) ...[
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onUnpin,
                        child: Text(
                          'Unpin',
                          style: TextStyle(
                            color: c.error,
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm dialog helper ─────────────────────────────────────────────────────

Future<bool> _confirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool isDestructive = false,
}) async {
  final c = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title,
          style: TextStyle(
              color: c.text,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600)),
      content: Text(body,
          style: TextStyle(
              color: c.textSecondary,
              fontFamily: 'Outfit',
              height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style: TextStyle(
                  color: c.textSecondary, fontFamily: 'Outfit')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDestructive ? c.error : c.primary,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
