import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/muted_chats_service.dart';
import '../../services/message_sync_manager.dart';
import '../../services/chat_api_service.dart';
import '../../widgets/common/verification_badge.dart';
import 'dart:async';

// ── Providers ─────────────────────────────────────────────────────────────────
final _channelsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await dioClient.get(AppEndpoints.myChannels);
  final data = res.data['data'];
  if (data is List) return List<Map<String, dynamic>>.from(data);
  if (data is Map && data['channels'] is List) {
    return List<Map<String, dynamic>>.from(data['channels'] as List);
  }
  return [];
});

final _mutedChatsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, userId) async {
  final list = await mutedChatsService.getUserMutedChats(userId);
  return list.map((m) => (m['mutedUserId'] ?? '').toString()).toSet();
});

// ── ChatScreen ────────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _tabIndex = 0;
  String _headerTitle = 'Chats';
  void Function()? _syncUnsub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (_tabCtrl.index != _tabIndex) {
          setState(() => _tabIndex = _tabCtrl.index);
        }
      });

    // Subscribe to sync status — drives header title reactively
    _syncUnsub = messageSyncManager.onStatusChange((status) {
      if (!mounted) return;
      final online = ref.read(chatProvider).isConnected;
      final title = status.syncing ? 'Updating...' : (online ? 'Chats' : 'Chats');
      if (_headerTitle != title) setState(() => _headerTitle = title);
    });
  }

  @override
  void dispose() {
    _syncUnsub?.call();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Header title follows sync status — never shows "Connecting..." permanently
    final isSyncing = ref.watch(chatProvider.select((s) => s.isSyncing));
    final title = isSyncing ? 'Updating...' : 'Chats';
    if (_headerTitle != title) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _headerTitle != title) setState(() => _headerTitle = title);
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            c.background.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(children: [
            _buildHeader(c),
            _buildTabBar(c),
            Expanded(child: TabBarView(
              controller: _tabCtrl,
              children: [
                _AllChatsList(tabIndex: _tabIndex),
                _PrivateChatList(),
                _GroupChatList(),
                _ChannelChatList(),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors c) => Container(
        color: c.background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              _headerTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: _tabIndex == 3
                ? GestureDetector(
                    onTap: () => context.push('/explore-channels'),
                    child: Icon(Icons.explore, size: 24, color: c.primary),
                  )
                : _tabIndex == 2
                    ? GestureDetector(
                        onTap: () => _showGroupMenu(context, c),
                        child: Icon(Icons.add_circle, size: 25, color: c.primary),
                      )
                    : const SizedBox.shrink(),
          ),
        ]),
      );

  Widget _buildTabBar(ThemeColors c) => Container(
        decoration: BoxDecoration(
          color: c.background,
          border: Border(
            bottom: BorderSide(
                color: c.border.withOpacity(0.3), width: 1),
          ),
        ),
        child: TabBar(
          controller: _tabCtrl,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 14),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 14),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Private'),
            Tab(text: 'Groups'),
            Tab(text: 'Channels'),
          ],
        ),
      );

  void _showGroupMenu(BuildContext context, ThemeColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: c.border, borderRadius: BorderRadius.circular(2)),
        ),
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
        SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
      ]),
    );
  }
}

// ── All Chats List ─────────────────────────────────────────────────────────────
// Mirrors AllChatsList.jsx: merges private + groups, sorted by last activity
class _AllChatsList extends ConsumerStatefulWidget {
  final int tabIndex;
  const _AllChatsList({required this.tabIndex});

  @override
  ConsumerState<_AllChatsList> createState() => _AllChatsListState();
}

class _AllChatsListState extends ConsumerState<_AllChatsList> {
  bool _refreshing = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    // Fetch on first mount if the store is empty (cold start or page first open)
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfEmpty());
  }

  Future<void> _fetchIfEmpty() async {
    final convs = ref.read(chatProvider).conversations;
    final groups = ref.read(chatProvider).groups;
    if (convs.isEmpty && groups.isEmpty) {
      await _refresh(showLoading: false);
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _refresh({bool showLoading = true}) async {
    if (showLoading) setState(() => _refreshing = true);
    final uid = ref.read(authProvider).uid;
    if (uid == null) {
      if (mounted) setState(() => _refreshing = false);
      return;
    }
    try {
      final chatNotifier = ref.read(chatProvider.notifier);
      final results = await Future.wait([
        chatApiService.getConversations(uid).catchError((_) => <Map<String, dynamic>>[]),
        chatApiService.getUserGroups(uid).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final convs = (results[0] as List<Map<String, dynamic>>)
          .map((e) => ChatConversation.fromJson(e))
          .toList();
      final groups = (results[1] as List<Map<String, dynamic>>)
          .map((e) => ChatConversation.fromJson(e))
          .toList();

      chatNotifier.setConversations(convs);
      chatNotifier.setGroups(groups);
    } catch (_) {}
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final conversations =
        ref.watch(chatProvider.select((s) => s.conversations));
    final groups = ref.watch(chatProvider.select((s) => s.groups));
    final onlineUsers =
        ref.watch(chatProvider.select((s) => s.onlineUsers));
    final mutedChatsAsync = ref.watch(_mutedChatsProvider(uid));
    final mutedChats = mutedChatsAsync.valueOrNull ?? {};

    // Merge and sort by last activity
    final all = <_ChatItem>[];
    for (final c in conversations) {
      final ts = c.updatedAt?.millisecondsSinceEpoch ??
          (c.lastMessageTime != null
              ? DateTime.tryParse(c.lastMessageTime!)?.millisecondsSinceEpoch
              : null) ??
          0;
      all.add(_ChatItem(conv: c, isGroup: false, ts: ts));
    }
    for (final g in groups) {
      final ts = g.updatedAt?.millisecondsSinceEpoch ??
          (g.lastMessageTime != null
              ? DateTime.tryParse(g.lastMessageTime!)?.millisecondsSinceEpoch
              : null) ??
          0;
      all.add(_ChatItem(conv: g, isGroup: true, ts: ts));
    }
    all.sort((a, b) => b.ts.compareTo(a.ts));

    // Show skeleton only on first load before any data arrives
    if (_initialLoading && all.isEmpty) {
      return _buildSkeleton(c);
    }

    if (all.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmpty(c, 'all'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: ListView.builder(
        itemCount: all.length,
        itemExtent: 88,
        itemBuilder: (ctx, i) {
          final item = all[i];
          final conv = item.conv;
          final isOnline = !item.isGroup &&
              conv.otherUserId != null &&
              onlineUsers.contains(conv.otherUserId);
          final isMuted = !item.isGroup &&
              conv.otherUserId != null &&
              mutedChats.contains(conv.otherUserId);
          return _ChatTile(
            conv: conv,
            isGroup: item.isGroup,
            isOnline: isOnline,
            isMuted: isMuted,
            currentUserId: uid,
            onLongPress: () => _onLongPress(context, conv, isMuted, uid),
          );
        },
      ),
    );
  }

  void _onLongPress(BuildContext context, ChatConversation conv,
      bool isMuted, String uid) {
    _showQuickActionsSheet(context, conv, isMuted, uid);
  }

  Widget _buildEmpty(ThemeColors c, String type) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: c.textTertiary),
            const SizedBox(height: 12),
            Text('No conversations yet',
                style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
                'Start chatting by visiting a profile\nand tapping the message button',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 14,
                    fontFamily: 'Outfit')),
          ],
        ),
      );

  Widget _buildSkeleton(ThemeColors c) => ListView.builder(
        itemCount: 8,
        itemExtent: 88,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: c.surface,
          highlightColor: c.border,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: c.surface),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 14,
                          width: 140,
                          decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(
                          height: 12,
                          width: 200,
                          decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(4))),
                    ]),
              ),
            ]),
          ),
        ),
      );
}

class _ChatItem {
  final ChatConversation conv;
  final bool isGroup;
  final int ts;
  const _ChatItem(
      {required this.conv, required this.isGroup, required this.ts});
}

// ── Private Chat List ──────────────────────────────────────────────────────────
class _PrivateChatList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PrivateChatList> createState() => _PrivateChatListState();
}

class _PrivateChatListState extends ConsumerState<_PrivateChatList> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final uid = ref.read(authProvider).uid;
    if (uid == null) {
      if (mounted) setState(() => _refreshing = false);
      return;
    }
    try {
      final convs = await chatApiService.getConversations(uid);
      ref.read(chatProvider.notifier).setConversations(
          convs.map((e) => ChatConversation.fromJson(e)).toList());
    } catch (_) {}
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final conversations =
        ref.watch(chatProvider.select((s) => s.conversations));
    final onlineUsers =
        ref.watch(chatProvider.select((s) => s.onlineUsers));
    final mutedChatsAsync = ref.watch(_mutedChatsProvider(uid));
    final mutedChats = mutedChatsAsync.valueOrNull ?? {};

    final pending = conversations.where((c) =>
        c.status == 'request_pending' && c.initiatorId != uid).toList();
    final active =
        conversations.where((c) => !(c.status == 'request_pending' && c.initiatorId != uid)).toList();

    if (conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: c.textTertiary),
                const SizedBox(height: 12),
                Text('No messages yet',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Start chatting by visiting a profile',
                    style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
              ]),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: ListView.builder(
        itemCount: active.length + (pending.isNotEmpty ? 1 : 0),
        itemExtent: 88,
        itemBuilder: (ctx, i) {
          if (pending.isNotEmpty && i == 0) {
            // Message requests banner
            return _MessageRequestsBanner(count: pending.length);
          }
          final conv =
              active[pending.isNotEmpty ? i - 1 : i];
          final isOnline = conv.otherUserId != null &&
              onlineUsers.contains(conv.otherUserId);
          final isMuted = conv.otherUserId != null &&
              mutedChats.contains(conv.otherUserId);
          return _ChatTile(
            conv: conv,
            isGroup: false,
            isOnline: isOnline,
            isMuted: isMuted,
            currentUserId: uid,
            onLongPress: () =>
                _showQuickActionsSheet(ctx, conv, isMuted, uid),
          );
        },
      ),
    );
  }
}

// ── Group Chat List ────────────────────────────────────────────────────────────
class _GroupChatList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GroupChatList> createState() => _GroupChatListState();
}

class _GroupChatListState extends ConsumerState<_GroupChatList> {
  Future<void> _refresh() async {
    final uid = ref.read(authProvider).uid;
    if (uid == null) return;
    try {
      final groups = await chatApiService.getUserGroups(uid);
      ref.read(chatProvider.notifier).setGroups(
          groups.map((e) => ChatConversation.fromJson(e)).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final groups = ref.watch(chatProvider.select((s) => s.groups));

    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.group_outlined, size: 64, color: c.textTertiary),
                const SizedBox(height: 12),
                Text('No groups yet',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Create or join a group to start',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 14,
                        fontFamily: 'Outfit')),
              ]),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: ListView.builder(
        itemCount: groups.length,
        itemExtent: 88,
        itemBuilder: (ctx, i) => _ChatTile(
          conv: groups[i],
          isGroup: true,
          isOnline: false,
          isMuted: false,
          currentUserId: uid,
        ),
      ),
    );
  }
}

// ── Channel List ───────────────────────────────────────────────────────────────
class _ChannelChatList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final channelsAsync = ref.watch(_channelsProvider);
    final uid = ref.watch(authProvider).uid ?? '';

    return channelsAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: c.primary)),
      error: (e, _) => Center(
          child: Text('Error loading channels',
              style: TextStyle(color: c.textTertiary))),
      data: (channels) {
        if (channels.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.campaign_outlined,
                  size: 64, color: c.textTertiary),
              const SizedBox(height: 12),
              Text('No channels yet',
                  style: TextStyle(
                      color: c.text,
                      fontSize: 18,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600)),
            ]),
          );
        }
        return ListView.builder(
          itemCount: channels.length,
          itemExtent: 88,
          itemBuilder: (ctx, i) {
            final ch = channels[i];
            final conv = ChatConversation(
              id: (ch['id'] ?? '').toString(),
              type: 'channel',
              name: ch['name'] ?? '',
              profilePic: ch['image'],
              lastMessage:
                  ch['last_message_content'] ?? ch['last_message'],
              lastMessageTime: ch['updated_at']?.toString(),
              unreadCount:
                  (ch['unread_count'] as num?)?.toInt() ?? 0,
            );
            return _ChatTile(
              conv: conv,
              isGroup: false,
              isOnline: false,
              isMuted: false,
              currentUserId: uid,
              isChannel: true,
            );
          },
        );
      },
    );
  }
}

// ── ChatTile ───────────────────────────────────────────────────────────────────
// Mirrors PrivateChatListItem from PrivateChatList.jsx
class _ChatTile extends StatelessWidget {
  final ChatConversation conv;
  final bool isGroup;
  final bool isChannel;
  final bool isOnline;
  final bool isMuted;
  final String currentUserId;
  final VoidCallback? onLongPress;

  const _ChatTile({
    required this.conv,
    required this.isGroup,
    required this.isOnline,
    required this.isMuted,
    required this.currentUserId,
    this.isChannel = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasUnread = conv.unreadCount > 0;
    final isMyMessage = conv.lastMessageSenderId == currentUserId;
    final otherUser = conv.otherUser;
    final iBlockedThem = conv.iBlockedThem;

    // Reaction vs message display
    DateTime? lastMsgTime = conv.lastMessageTime != null
        ? DateTime.tryParse(conv.lastMessageTime!)
        : null;
    DateTime? lastReactionTime = conv.lastReactionAt != null
        ? DateTime.tryParse(conv.lastReactionAt!)
        : null;
    final isLastActivityReaction = lastReactionTime != null &&
        lastMsgTime != null &&
        lastReactionTime.isAfter(lastMsgTime) &&
        conv.lastReactionEmoji != null;
    final isMyReaction =
        conv.lastReactionUserId == currentUserId;
    final displayTime =
        isLastActivityReaction ? lastReactionTime : lastMsgTime;

    String lastMsgPreview = '';
    if (iBlockedThem) {
      lastMsgPreview = 'User is blocked';
    } else if (isLastActivityReaction) {
      final preview = conv.lastReactionMessageContent ?? 'a message';
      final short = preview.length > 20
          ? '${preview.substring(0, 20)}...'
          : preview;
      lastMsgPreview = isMyReaction
          ? 'You reacted ${conv.lastReactionEmoji} to "$short"'
          : 'Reacted ${conv.lastReactionEmoji} to "$short"';
    } else if (conv.lastMessageTime == null) {
      lastMsgPreview = isGroup ? 'No messages yet' : '';
    } else {
      switch (conv.lastMessageType) {
        case 'voice':
          lastMsgPreview = '🎤 Voice Message';
          break;
        case 'image':
          lastMsgPreview = '🌄 Photo';
          break;
        case 'video':
          lastMsgPreview = '🎥 Video';
          break;
        case 'audio':
          lastMsgPreview = '🎵 Audio';
          break;
        case 'shared_topic':
        case 'topic_reference':
          lastMsgPreview = '📋 Topic';
          break;
        case 'giphy_sticker':
        case 'sticker':
          lastMsgPreview = '🎭 Sticker';
          break;
        case 'giphy_gif':
          lastMsgPreview = '🎬 GIF';
          break;
        case 'poll':
          lastMsgPreview = '📊 Poll';
          break;
        default:
          lastMsgPreview = conv.lastMessage ?? '';
      }
    }

    final timeStr = displayTime != null
        ? _formatChatListTime(displayTime)
        : '';

    return Material(
      color: c.background,
      child: InkWell(
        onTap: () {
          if (isChannel) {
            context.push('/channel/${conv.id}');
          } else if (isGroup) {
            context.push('/chat/group/${conv.id}');
          } else {
            context.push('/chat/conversation/${conv.id}',
                extra: {
                  'otherUser': otherUser,
                  'status': conv.status,
                  'initiatorId': conv.initiatorId,
                });
          }
        },
        onLongPress: onLongPress,
        splashColor: c.border.withOpacity(0.3),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: c.border.withOpacity(0.15), width: 0.5),
            ),
          ),
          child: Row(children: [
            // Avatar
            Stack(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: c.surface,
                backgroundImage: conv.profilePic != null
                    ? CachedNetworkImageProvider(conv.profilePic!)
                    : null,
                child: conv.profilePic == null
                    ? Text(
                        (conv.name.isNotEmpty ? conv.name[0] : '?')
                            .toUpperCase(),
                        style: TextStyle(
                            color: c.text,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 18))
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.background, width: 2),
                    ),
                  ),
                ),
              if (isGroup)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: c.background, shape: BoxShape.circle),
                    child: Icon(Icons.group,
                        size: 14, color: c.primary),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(children: [
                          Flexible(
                            child: Text(
                              conv.name,
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
                          if (otherUser?['is_verified'] == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: VerificationBadge(
                                isVerified: true,
                                badge: otherUser?['verification_badge'],
                                size: 15,
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          color: hasUnread
                              ? c.primary
                              : c.textSecondary,
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (isMyMessage && !iBlockedThem && !isLastActivityReaction)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          conv.lastMessageStatus == 'pending'
                              ? Icons.access_time
                              : Icons.done_all,
                          size: 16,
                          color: conv.lastMessageStatus == 'pending'
                              ? c.textTertiary
                              : conv.lastMessageIsRead
                                  ? c.primary
                                  : c.textTertiary,
                        ),
                      ),
                    if (iBlockedThem)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.block,
                            size: 14,
                            color: const Color(0xFFFF5252)),
                      ),
                    Expanded(
                      child: Text(
                        lastMsgPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: iBlockedThem
                              ? const Color(0xFFFF5252)
                              : hasUnread
                                  ? c.text
                                  : c.textSecondary,
                          fontStyle: iBlockedThem
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (isMuted)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.notifications_off,
                            size: 14, color: c.textSecondary),
                      ),
                    if (hasUnread && !iBlockedThem) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          conv.unreadCount > 99
                              ? '99+'
                              : conv.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

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
    if (dt.year == now.year) {
      return '${dt.day}/${dt.month}';
    }
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}

// ── Message Requests Banner ────────────────────────────────────────────────────
class _MessageRequestsBanner extends StatelessWidget {
  final int count;
  const _MessageRequestsBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: () => context.push('/chat/requests'),
        child: Container(
          height: 88,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: c.border.withOpacity(0.15), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mail_outline,
                    color: c.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Message Requests',
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 22, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick actions bottom sheet ─────────────────────────────────────────────────
void _showQuickActionsSheet(BuildContext context, ChatConversation conv,
    bool isMuted, String currentUserId) {
  final c = context.colors;
  final otherUser = conv.otherUser;
  final otherUserId = conv.otherUserId ?? '';
  final otherUserName =
      otherUser?['name'] ?? otherUser?['username'] ?? conv.name;

  showModalBottomSheet(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        // Header with avatar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: c.surface,
              backgroundImage: conv.profilePic != null
                  ? CachedNetworkImageProvider(conv.profilePic!)
                  : null,
              child: conv.profilePic == null
                  ? Text(
                      (conv.name.isNotEmpty ? conv.name[0] : '?')
                          .toUpperCase(),
                      style: TextStyle(
                          color: c.text,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600))
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              otherUserName,
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: c.text),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: c.border),
        ListTile(
          leading: Icon(
              isMuted ? Icons.notifications_active : Icons.notifications_off,
              color: c.text),
          title: Text(
            isMuted ? 'Unmute Notifications' : 'Mute Notifications',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500),
          ),
          onTap: () {
            Navigator.pop(ctx);
            // TODO: show mute duration picker
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: c.error),
          title: Text('Delete Chat',
              style: TextStyle(
                  color: c.error,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500)),
          onTap: () {
            Navigator.pop(ctx);
            _confirmDeleteChat(context, conv, currentUserId);
          },
        ),
        SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
      ]),
    ),
  );
}

void _confirmDeleteChat(
    BuildContext context, ChatConversation conv, String currentUserId) {
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
          style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel',
              style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Will be wired to chatProvider.notifier.deleteConversation in ChatConversationScreen
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

// chatApiService is imported from '../../services/chat_api_service.dart'
