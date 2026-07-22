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
    return '${(diff.inDays / 7).floor()}w ago';
  } catch (_) {
    return '';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PendingRequestsScreen extends ConsumerStatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  ConsumerState<PendingRequestsScreen> createState() =>
      _PendingRequestsScreenState();
}

class _PendingRequestsScreenState
    extends ConsumerState<PendingRequestsScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Outgoing pending requests: conversations where I initiated and
      // status is pending (request_pending).
      final uid = ref.read(authProvider).uid ?? '';
      final res = await dioClient.get(
        AppEndpoints.userConversations(uid),
        queryParameters: {'status': 'request_pending', 'role': 'sender'},
      );
      final data = res.data['data'];
      List<Map<String, dynamic>> items = [];
      if (data is List) {
        items = List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data['conversations'] is List) {
        items = List<Map<String, dynamic>>.from(
            data['conversations'] as List);
      }
      if (mounted) setState(() { _pending = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRequest(String conversationId) async {
    final confirmed = await _confirmDialog(
      context: context,
      title: 'Cancel Request',
      body: 'This will cancel your message request. The person will not be notified.',
      confirmLabel: 'Cancel Request',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await chatApiService.deleteConversation(conversationId);
      if (mounted) {
        setState(() =>
            _pending.removeWhere((r) => r['id']?.toString() == conversationId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel request')));
      }
    }
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
          'Pending Requests',
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
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: () => _load()),
                if (_pending.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty_outlined,
                              size: 64, color: c.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'No pending requests',
                            style: TextStyle(
                              color: c.text,
                              fontSize: 18,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Message requests you\'ve sent\nwill appear here until accepted',
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
                        (_, index) {
                          final i = index ~/ 2;
                          if (index.isOdd) {
                            return Divider(
                                color: c.border, height: 1, indent: 80);
                          }
                          return _PendingTile(
                            conversation: _pending[i],
                            onCancel: () => _cancelRequest(
                                _pending[i]['id']?.toString() ?? ''),
                          );
                        },
                        childCount: _pending.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Pending tile ──────────────────────────────────────────────────────────────

class _PendingTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onCancel;

  const _PendingTile({required this.conversation, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Other participant
    final otherUser =
        conversation['other_user'] as Map<String, dynamic>? ??
        conversation['recipient'] as Map<String, dynamic>? ??
        {};
    final name = otherUser['name']?.toString() ??
        otherUser['username']?.toString() ??
        '';
    final pic = otherUser['profile_pic']?.toString();
    final lastMessage = conversation['last_message']?.toString() ??
        conversation['preview']?.toString() ??
        'Message request sent';
    final sentAt = conversation['updated_at']?.toString() ??
        conversation['created_at']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: c.border,
                backgroundImage: pic != null
                    ? CachedNetworkImageProvider(pic)
                    : null,
                child: pic == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 18,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      _timeAgo(sentAt),
                      style: TextStyle(
                        color: c.textTertiary,
                        fontFamily: 'Outfit',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Outfit',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                // Pending badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: c.warning,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.error.withOpacity(0.3)),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: c.error,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
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
          child: Text('Back',
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
