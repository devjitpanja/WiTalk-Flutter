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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  } catch (_) {
    return '';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MessageRequestsScreen extends ConsumerStatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  ConsumerState<MessageRequestsScreen> createState() =>
      _MessageRequestsScreenState();
}

class _MessageRequestsScreenState
    extends ConsumerState<MessageRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) setState(() => _refreshing = true);
    try {
      final items = await chatApiService.getMessageRequests();
      if (mounted) {
        setState(() {
          _requests = items;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _refreshing = false; });
    }
  }

  void _removeRequest(String id) {
    setState(() => _requests.removeWhere((r) => r['id']?.toString() == id));
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
          'Message Requests',
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
          : RefreshIndicator(
              color: c.primary,
              backgroundColor: c.surface,
              onRefresh: () => _load(refresh: true),
              child: _requests.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mark_chat_unread_outlined,
                                    size: 64, color: c.textTertiary),
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
                                const SizedBox(height: 6),
                                Text(
                                  'New requests from people you\ndon\'t follow will appear here',
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
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: c.border, height: 1, indent: 80),
                      itemBuilder: (_, i) => _RequestTile(
                        request: _requests[i],
                        onRemove: () =>
                            _removeRequest(_requests[i]['id']?.toString() ?? ''),
                      ),
                    ),
            ),
    );
  }
}

// ── Request tile ──────────────────────────────────────────────────────────────

class _RequestTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onRemove;

  const _RequestTile({required this.request, required this.onRemove});

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() => _processing = true);
    try {
      final id = widget.request['id']?.toString() ?? '';
      // Accept via conversation accept endpoint
      await chatApiService.acceptConversation(id);
      if (mounted) {
        widget.onRemove();
        final c = context.colors;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request accepted',
              style:
                  TextStyle(fontFamily: 'Outfit', color: c.text)),
          backgroundColor: c.surface,
          duration: const Duration(seconds: 2),
        ));
        // Navigate into the conversation
        context.push('/chat/conversation/$id');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to accept request')));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDialog(
      context: context,
      title: 'Delete Request',
      body: 'This will remove the request. You can still receive messages from this person if they send a new one.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _processing = true);
    try {
      final id = widget.request['id']?.toString() ?? '';
      await chatApiService.deleteConversation(id);
      if (mounted) widget.onRemove();
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete request')));
      }
    }
  }

  Future<void> _block() async {
    final user =
        widget.request['from_user'] as Map<String, dynamic>? ?? {};
    final name = user['name']?.toString() ?? 'this user';
    final confirmed = await _confirmDialog(
      context: context,
      title: 'Block $name?',
      body: 'They will not be able to message you. This action can be undone from your blocked accounts list.',
      confirmLabel: 'Block',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _processing = true);
    try {
      final userId = user['id']?.toString() ?? user['uid']?.toString() ?? '';
      if (userId.isNotEmpty) {
        await dioClient.post(AppEndpoints.blockUser,
            data: {'blocked_user_id': userId});
      }
      // Also delete the conversation
      final id = widget.request['id']?.toString() ?? '';
      await chatApiService.deleteConversation(id);
      if (mounted) widget.onRemove();
    } catch (_) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to block user')));
      }
    }
  }

  void _showActions() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: c.success),
              title: Text('Accept',
                  style: TextStyle(
                      color: c.text,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _accept();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: c.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: c.error,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _delete();
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.block_outlined, color: c.error),
              title: Text('Block',
                  style: TextStyle(
                      color: c.error,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _block();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user =
        widget.request['from_user'] as Map<String, dynamic>? ?? {};
    final name = user['name']?.toString() ?? user['username']?.toString() ?? '';
    final pic = user['profile_pic']?.toString();
    final preview = widget.request['last_message']?.toString() ??
        widget.request['preview']?.toString() ??
        'Wants to message you';
    final timestamp = widget.request['updated_at']?.toString() ??
        widget.request['created_at']?.toString();

    return GestureDetector(
      onTap: _processing ? null : _showActions,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
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
                        _timeAgo(timestamp),
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
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontFamily: 'Outfit',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Accept / Delete inline buttons
                  if (!_processing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _delete,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: c.border),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primaryButton,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(
                      height: 28,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
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
              color: c.textSecondary, fontFamily: 'Outfit', height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style:
                  TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
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
