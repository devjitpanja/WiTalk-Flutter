import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

class BannedUsersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const BannedUsersScreen({super.key, required this.groupId});

  @override
  ConsumerState<BannedUsersScreen> createState() => _BannedUsersScreenState();
}

class _BannedUsersScreenState extends ConsumerState<BannedUsersScreen> {
  List<Map<String, dynamic>> _bannedUsers = [];
  bool _loading = true;
  String? _error;
  final Set<String> _unbanning = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await chatApiService.getGroupBannedUsers(widget.groupId);
      setState(() => _bannedUsers = data);
    } catch (_) {
      setState(() => _error = 'Failed to load banned users.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unban(Map<String, dynamic> user) async {
    final userId =
        user['user_id']?.toString() ?? user['id']?.toString() ?? '';
    if (userId.isEmpty || _unbanning.contains(userId)) return;

    final c = context.colors;
    final name =
        user['name'] as String? ?? user['username'] as String? ?? 'User';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unban $name?',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '$name will be able to rejoin this group.',
          style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Unban',
              style: TextStyle(
                color: c.success,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _unbanning.add(userId));
    try {
      await chatApiService.unbanGroupMember(widget.groupId, userId);
      setState(() => _bannedUsers
          .removeWhere((u) => u['user_id']?.toString() == userId || u['id']?.toString() == userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name has been unbanned.',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to unban user. Try again.',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _unbanning.remove(userId));
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
          'Banned Users',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.text),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primaryButton))
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                  c: c,
                )
              : _bannedUsers.isEmpty
                  ? _EmptyState(c: c)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _bannedUsers.length,
                      itemBuilder: (_, i) {
                        final user = _bannedUsers[i];
                        return _BannedUserTile(
                          user: user,
                          c: c,
                          isUnbanning: _unbanning.contains(
                            user['user_id']?.toString() ??
                                user['id']?.toString() ??
                                '',
                          ),
                          onUnban: () => _unban(user),
                        );
                      },
                    ),
    );
  }
}

class _BannedUserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final ThemeColors c;
  final bool isUnbanning;
  final VoidCallback onUnban;

  const _BannedUserTile({
    required this.user,
    required this.c,
    required this.isUnbanning,
    required this.onUnban,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ??
        user['username'] as String? ??
        'Unknown User';
    final pic = user['profile_pic'] as String? ?? user['avatar'] as String?;
    final reason = user['reason'] as String? ?? user['ban_reason'] as String?;
    final bannedAt = user['banned_at'] as String? ??
        user['created_at'] as String?;
    final bannedByName = user['banned_by_name'] as String? ??
        (user['banned_by'] as Map?)?['name'] as String?;

    String? formattedDate;
    if (bannedAt != null) {
      try {
        final dt = DateTime.parse(bannedAt).toLocal();
        formattedDate =
            '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.error.withOpacity(0.15),
            backgroundImage:
                pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: c.error,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.block, size: 12, color: c.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontFamily: 'Outfit',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (formattedDate != null || bannedByName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (formattedDate != null) 'Banned $formattedDate',
                      if (bannedByName != null) 'by $bannedByName',
                    ].join(' '),
                    style: TextStyle(
                      color: c.textTertiary,
                      fontFamily: 'Outfit',
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: isUnbanning
                ? Padding(
                    padding: const EdgeInsets.all(7),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primaryButton,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: onUnban,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.success,
                      side: BorderSide(color: c.success),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Unban',
                      style: TextStyle(
                        color: c.success,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_reg_outlined, size: 64, color: c.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No Banned Users',
            style: TextStyle(
              color: c.text,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This group has no banned members.',
            style: TextStyle(
              color: c.textSecondary,
              fontFamily: 'Outfit',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ThemeColors c;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontFamily: 'Outfit',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.primaryButton),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: c.primaryButton,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
