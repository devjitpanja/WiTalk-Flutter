import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_api_service.dart';

// Standalone group list (also accessible from navigation)
// Mirrors GroupListScreen.jsx
class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() =>
      _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final uid = ref.read(authProvider).uid;
    if (uid == null) {
      setState(() => _refreshing = false);
      return;
    }
    try {
      final groups = await chatApiService.getUserGroups(uid);
      ref.read(chatProvider.notifier).setGroups(
          groups.map((e) => ChatConversation.fromJson(e)).toList());
    } catch (_) {}
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = ref.watch(chatProvider.select((s) => s.groups));
    final uid = ref.watch(authProvider).uid ?? '';

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text('Groups',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group_add_outlined, color: c.primary),
            onPressed: () => _showGroupMenu(context, c),
          ),
        ],
      ),
      body: groups.isEmpty && !_refreshing
          ? _buildEmpty(c)
          : RefreshIndicator(
              onRefresh: _refresh,
              color: c.primary,
              child: ListView.builder(
                itemCount: groups.length,
                itemExtent: 88,
                itemBuilder: (ctx, i) => _GroupTile(
                    group: groups[i], currentUserId: uid, c: c),
              ),
            ),
    );
  }

  Widget _buildEmpty(ThemeColors c) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group_outlined, size: 64, color: c.textTertiary),
          const SizedBox(height: 12),
          Text('No groups yet',
              style: TextStyle(
                  color: c.text,
                  fontSize: 18,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/chat/create-group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Group',
                style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  void _showGroupMenu(BuildContext context, ThemeColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.group_add, color: c.text),
            title: Text('Create New Group',
                style: TextStyle(
                    color: c.text,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              context.push('/chat/create-group');
            },
          ),
          Divider(height: 1, color: c.border),
          ListTile(
            leading: Icon(Icons.login, color: c.text),
            title: Text('Join Group by Code',
                style: TextStyle(
                    color: c.text,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              context.push('/chat/join-group');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ChatConversation group;
  final String currentUserId;
  final ThemeColors c;

  const _GroupTile(
      {required this.group,
      required this.currentUserId,
      required this.c});

  @override
  Widget build(BuildContext context) {
    final hasUnread = group.unreadCount > 0;
    final isMyMessage = group.lastMessageSenderId == currentUserId;

    String lastMsgPreview = '';
    switch (group.lastMessageType) {
      case 'voice':
        lastMsgPreview = '🎤 Voice Message';
        break;
      case 'image':
        lastMsgPreview = '🌄 Photo';
        break;
      case 'video':
        lastMsgPreview = '🎥 Video';
        break;
      default:
        lastMsgPreview = group.lastMessage ?? 'No messages yet';
    }

    String timeStr = '';
    if (group.lastMessageTime != null) {
      final dt = DateTime.tryParse(group.lastMessageTime!);
      if (dt != null) {
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) {
          timeStr = '${diff.inMinutes}m';
        } else if (diff.inHours < 24) {
          final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
          final m = dt.minute.toString().padLeft(2, '0');
          final period = dt.hour >= 12 ? 'PM' : 'AM';
          timeStr = '$h:$m $period';
        } else {
          timeStr = '${dt.day}/${dt.month}';
        }
      }
    }

    return Material(
      color: c.background,
      child: InkWell(
        onTap: () => context.push('/chat/group/${group.id}'),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: c.border.withOpacity(0.15), width: 0.5),
            ),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: c.surface,
              backgroundImage: group.profilePic != null
                  ? CachedNetworkImageProvider(group.profilePic!)
                  : null,
              child: group.profilePic == null
                  ? Text(
                      (group.name.isNotEmpty ? group.name[0] : '?')
                          .toUpperCase(),
                      style: TextStyle(
                          color: c.text,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 18))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Outfit',
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: c.text,
                        ),
                      ),
                    ),
                    Text(timeStr,
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Outfit',
                            color: hasUnread
                                ? c.primary
                                : c.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: Text(
                        lastMsgPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          color: hasUnread
                              ? c.text
                              : c.textSecondary,
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          group.unreadCount > 99
                              ? '99+'
                              : group.unreadCount.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

final chatApiService = ChatApiService();
