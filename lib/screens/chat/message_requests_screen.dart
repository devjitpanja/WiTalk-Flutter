import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_api_service.dart';
import '../../widgets/common/verification_badge.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class MessageRequestsScreen extends ConsumerWidget {
  const MessageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final conversations = ref.watch(
      chatProvider.select((s) => s.conversations),
    );

    final pendingRequests = conversations
        .where((cv) =>
            cv.status == 'request_pending' && cv.initiatorId != uid)
        .toList();

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
          'Message Requests',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _refresh(ref)),
          if (pendingRequests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline,
                          size: 56, color: c.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'No message requests',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 18,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "When someone you don't follow messages you, their request will appear here.",
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
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _RequestTile(conv: pendingRequests[i]),
                childCount: pendingRequests.length,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    final uid = ref.read(authProvider).uid;
    if (uid == null) return;
    try {
      final convsList = await chatApiService
          .getConversations(uid)
          .catchError((_) => <Map<String, dynamic>>[]);
      final convs = convsList.map((e) => ChatConversation.fromJson(e)).toList();
      ref.read(chatProvider.notifier).setConversations(convs);
    } catch (_) {}
  }
}

// ── Request tile ──────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final ChatConversation conv;

  const _RequestTile({required this.conv});

  String _getPreview() {
    if (conv.lastMessageTime == null) return 'Sent a message request';
    switch (conv.lastMessageType) {
      case 'voice':
        return '🎤 Voice Message';
      case 'image':
        return '🌄 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎵 Audio';
      default:
        return conv.lastMessage?.isNotEmpty == true
            ? conv.lastMessage!
            : 'Sent a message request';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final otherUser = conv.otherUser ?? {};
    final name =
        otherUser['name']?.toString() ?? otherUser['username']?.toString() ?? conv.name;
    final pic = conv.profilePic;
    final hasUnread = conv.unreadCount > 0;
    final displayTime = conv.lastMessageTime != null
        ? _formatChatListTime(DateTime.tryParse(conv.lastMessageTime!)?.toLocal() ??
            DateTime.now())
        : '';

    return InkWell(
      onTap: () => context.push(
        '/chat/conversation/${conv.id}',
        extra: {
          'otherUser': conv.otherUser,
          'status': conv.status,
          'initiatorId': conv.initiatorId,
        },
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 27,
              backgroundColor: c.surface,
              backgroundImage: pic != null && pic.isNotEmpty
                  ? CachedNetworkImageProvider(pic)
                  : null,
              child: (pic == null || pic.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row + time
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.text,
                                  fontFamily: 'Outfit',
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            VerificationBadge(
                              isVerified:
                                  otherUser['is_verified'] == true,
                              badge: otherUser['verification_badge']
                                  as Map<String, dynamic>?,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        displayTime,
                        style: TextStyle(
                          color: hasUnread ? c.primary : c.textSecondary,
                          fontFamily: 'Outfit',
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Preview row + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getPreview(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? c.text : c.textSecondary,
                            fontFamily: 'Outfit',
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                              minWidth: 20, maxHeight: 20),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            conv.unreadCount > 99
                                ? '99+'
                                : conv.unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time formatter (mirrors RN formatChatListTime) ────────────────────────────
String _formatChatListTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24 &&
      dt.day == now.day &&
      dt.month == now.month &&
      dt.year == now.year) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayH:$m $period';
  }
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
  if (dt.year == now.year) return '${dt.day}/${dt.month}';
  return '${dt.day}/${dt.month}/${dt.year % 100}';
}
