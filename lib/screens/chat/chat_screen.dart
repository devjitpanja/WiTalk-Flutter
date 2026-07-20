import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/muted_chats_service.dart';
import '../../services/muted_groups_service.dart';
import '../../services/message_sync_manager.dart';
import '../../services/chat_api_service.dart';
import '../../widgets/common/verification_badge.dart';


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

    _syncUnsub = messageSyncManager.onStatusChange((status) {
      if (!mounted) return;
      final title = status.syncing ? 'Updating...' : 'Chats';
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
                color: c.border.withValues(alpha: 0.3), width: 1),
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

  // RN uses a top-right dropdown modal, not a BottomSheet
  void _showGroupMenu(BuildContext context, ThemeColors c) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.topRight(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      items: [
        PopupMenuItem<String>(
          value: 'create',
          child: Row(children: [
            Icon(Icons.group_add, size: 24, color: c.text),
            const SizedBox(width: 12),
            Text('Create New Group',
                style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                    color: c.text)),
          ]),
        ),
        PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'join',
          child: Row(children: [
            Icon(Icons.login, size: 24, color: c.text),
            const SizedBox(width: 12),
            Text('Join Group by Code',
                style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w500,
                    color: c.text)),
          ]),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'create') context.push('/chat/create-group');
      if (value == 'join') context.push('/chat/join-group');
    });
  }
}

// ── All Chats List ─────────────────────────────────────────────────────────────
// Mirrors AllChatsList.jsx: merges private + groups + channels, sorted by last activity
class _AllChatsList extends ConsumerStatefulWidget {
  final int tabIndex;
  const _AllChatsList({required this.tabIndex});

  @override
  ConsumerState<_AllChatsList> createState() => _AllChatsListState();
}

class _AllChatsListState extends ConsumerState<_AllChatsList> {
  bool _initialLoading = true;
  List<Map<String, dynamic>> _channels = [];
  Timer? _sortDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfEmpty());
  }

  @override
  void dispose() {
    _sortDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchIfEmpty() async {
    final convs = ref.read(chatProvider).conversations;
    final groups = ref.read(chatProvider).groups;
    if (convs.isEmpty && groups.isEmpty) {
      await _refresh(showLoading: false);
    } else {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _refresh({bool showLoading = true}) async {
    final uid = ref.read(authProvider).uid;
    if (uid == null) {
      if (mounted) setState(() => _initialLoading = false);
      return;
    }
    try {
      final chatNotifier = ref.read(chatProvider.notifier);
      final convsFuture = chatApiService.getConversations(uid).catchError((_) => <Map<String, dynamic>>[]);
      final groupsFuture = chatApiService.getUserGroups(uid).catchError((_) => <Map<String, dynamic>>[]);
      final channelsFuture = _fetchChannels();
      final mutedChatsFuture = _fetchMutedChats(uid);
      final mutedGroupsFuture = _fetchMutedGroups(uid);

      final convsList = await convsFuture;
      final groupsList = await groupsFuture;
      final channels = await channelsFuture;
      final mutedChats = await mutedChatsFuture;
      final mutedGroups = await mutedGroupsFuture;

      final convs = convsList.map((e) => ChatConversation.fromJson(e)).toList();
      final groups = groupsList.map((e) => ChatConversation.fromJson(e)).toList();

      chatNotifier.setConversations(convs);
      chatNotifier.setGroups(groups);
      chatNotifier.setMutedChats(mutedChats);
      chatNotifier.setMutedGroups(mutedGroups);

      if (mounted) setState(() => _channels = channels);
    } catch (_) {}
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchChannels() async {
    try {
      final res = await dioClient.get(AppEndpoints.myChannels);
      final data = res.data['data'];
      if (data is Map && data['channels'] is List) {
        return List<Map<String, dynamic>>.from(data['channels'] as List);
      }
      if (data is List) return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  Future<Set<String>> _fetchMutedChats(String uid) async {
    try {
      final list = await mutedChatsService.getUserMutedChats(uid);
      return list.map((m) => (m['mutedUserId'] ?? '').toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> _fetchMutedGroups(String uid) async {
    try {
      final list = await mutedGroupsService.getUserMutedGroups(uid);
      return {for (final m in list) (m['groupId'] ?? '').toString(): (m['notificationType'] ?? '').toString()};
    } catch (_) {
      return {};
    }
  }

  List<_CombinedItem> _buildCombinedList(
    List<ChatConversation> conversations,
    List<ChatConversation> groups,
    List<Map<String, dynamic>> channels,
    String uid,
  ) {
    final pending = <ChatConversation>[];
    final active = <ChatConversation>[];
    for (final c in conversations) {
      if (c.status == 'request_pending' && c.initiatorId != uid) {
        pending.add(c);
      } else {
        active.add(c);
      }
    }

    final items = <_CombinedItem>[];

    for (final c in active) {
      final msgTs = c.lastMessageTime != null
          ? DateTime.tryParse(c.lastMessageTime!)?.millisecondsSinceEpoch ?? 0
          : 0;
      final reactTs = c.lastReactionAt != null
          ? DateTime.tryParse(c.lastReactionAt!)?.millisecondsSinceEpoch ?? 0
          : 0;
      items.add(_CombinedItem(
        type: 'private',
        conv: c,
        ts: msgTs > reactTs ? msgTs : reactTs,
      ));
    }

    for (final g in groups) {
      final ts = g.updatedAt?.millisecondsSinceEpoch ??
          (g.lastMessageTime != null
              ? DateTime.tryParse(g.lastMessageTime!)?.millisecondsSinceEpoch
              : null) ??
          0;
      items.add(_CombinedItem(type: 'group', conv: g, ts: ts));
    }

    for (final ch in channels) {
      final ts = ch['last_message_at'] != null
          ? (DateTime.tryParse(ch['last_message_at'].toString())
                  ?.millisecondsSinceEpoch ??
              0)
          : 0;
      items.add(_CombinedItem(type: 'channel', channelData: ch, ts: ts));
    }

    items.sort((a, b) => b.ts.compareTo(a.ts));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final conversations = ref.watch(chatProvider.select((s) => s.conversations));
    final groups = ref.watch(chatProvider.select((s) => s.groups));
    final onlineUsers = ref.watch(chatProvider.select((s) => s.onlineUsers));
    final mutedChats = ref.watch(chatProvider.select((s) => s.mutedChats));
    final mutedGroups = ref.watch(chatProvider.select((s) => s.mutedGroups));

    final pendingRequests = conversations
        .where((c) => c.status == 'request_pending' && c.initiatorId != uid)
        .toList();

    final combined = _buildCombinedList(conversations, groups, _channels, uid);

    if (_initialLoading && combined.isEmpty) {
      return _buildSkeleton(c);
    }

    if (combined.isEmpty && pendingRequests.isEmpty) {
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
                const SizedBox(height: 16),
                Text('No chats yet',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                    'Start a conversation or join a group\nto see your chats here',
                    textAlign: TextAlign.center,
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

    final listCount = combined.length + (pendingRequests.isNotEmpty ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: ListView.builder(
        itemCount: listCount,
        itemBuilder: (ctx, i) {
          // Message requests banner at top
          if (pendingRequests.isNotEmpty && i == 0) {
            return _MessageRequestsBanner(count: pendingRequests.length);
          }
          final item = combined[pendingRequests.isNotEmpty ? i - 1 : i];

          if (item.type == 'channel') {
            final ch = item.channelData!;
            return _ChannelTile(channelData: ch, currentUserId: uid);
          }

          if (item.type == 'group') {
            final conv = item.conv!;
            final isGroupMuted = mutedGroups[conv.id] == 'muted';
            return _ChatTile(
              conv: conv,
              isGroup: true,
              isOnline: false,
              isMuted: isGroupMuted,
              currentUserId: uid,
            );
          }

          // private
          final conv = item.conv!;
          final theyBlockedMe = conv.theyBlockedMe;
          final isOnline = !theyBlockedMe &&
              conv.status != 'request_pending' &&
              conv.otherUserId != null &&
              onlineUsers.contains(conv.otherUserId);
          final isMuted = conv.otherUserId != null &&
              mutedChats.contains(conv.otherUserId);
          return _ChatTile(
            conv: conv,
            isGroup: false,
            isOnline: isOnline,
            isMuted: isMuted,
            currentUserId: uid,
            onLongPress: () => _showQuickActionsSheet(context, conv, isMuted, uid),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton(ThemeColors c) => ListView.builder(
        itemCount: 9,
        itemBuilder: (context, i) => Shimmer.fromColors(
          baseColor: c.surface,
          highlightColor: c.border,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                              borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Container(
                          height: 12,
                          width: 200,
                          decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(6))),
                    ]),
              ),
              const SizedBox(width: 12),
              Container(
                  height: 11,
                  width: 34,
                  decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(4))),
            ]),
          ),
        ),
      );
}

class _CombinedItem {
  final String type; // 'private' | 'group' | 'channel'
  final ChatConversation? conv;
  final Map<String, dynamic>? channelData;
  final int ts;
  const _CombinedItem({
    required this.type,
    this.conv,
    this.channelData,
    required this.ts,
  });
}

// ── Private Chat List ──────────────────────────────────────────────────────────
class _PrivateChatList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PrivateChatList> createState() => _PrivateChatListState();
}

class _PrivateChatListState extends ConsumerState<_PrivateChatList> {
  Future<void> _refresh() async {
    final uid = ref.read(authProvider).uid;
    if (uid == null) return;
    try {
      final convsList = await chatApiService.getConversations(uid).catchError((_) => <Map<String, dynamic>>[]);
      final mutedList = await mutedChatsService.getUserMutedChats(uid).catchError((_) => <Map<String, dynamic>>[]);
      final convs = convsList.map((e) => ChatConversation.fromJson(e)).toList();
      final mutedSet = mutedList.map((m) => (m['mutedUserId'] ?? '').toString()).toSet();
      ref.read(chatProvider.notifier).setConversations(convs);
      ref.read(chatProvider.notifier).setMutedChats(mutedSet);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final conversations = ref.watch(chatProvider.select((s) => s.conversations));
    final onlineUsers = ref.watch(chatProvider.select((s) => s.onlineUsers));
    final mutedChats = ref.watch(chatProvider.select((s) => s.mutedChats));

    final pending = conversations
        .where((c) => c.status == 'request_pending' && c.initiatorId != uid)
        .toList();
    final active = conversations
        .where((c) => !(c.status == 'request_pending' && c.initiatorId != uid))
        .toList();

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
                const SizedBox(height: 16),
                Text('No conversations yet',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Start chatting by visiting a profile\nand tapping the message button',
                    textAlign: TextAlign.center,
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
        itemCount: active.length + (pending.isNotEmpty ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (pending.isNotEmpty && i == 0) {
            return _MessageRequestsBanner(count: pending.length);
          }
          final conv = active[pending.isNotEmpty ? i - 1 : i];
          final theyBlockedMe = conv.theyBlockedMe;
          final isOnline = !theyBlockedMe &&
              conv.status != 'request_pending' &&
              conv.otherUserId != null &&
              onlineUsers.contains(conv.otherUserId);
          final isMuted =
              conv.otherUserId != null && mutedChats.contains(conv.otherUserId);
          return _ChatTile(
            conv: conv,
            isGroup: false,
            isOnline: isOnline,
            isMuted: isMuted,
            currentUserId: uid,
            onLongPress: () => _showQuickActionsSheet(ctx, conv, isMuted, uid),
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
      final groupsList = await chatApiService.getUserGroups(uid).catchError((_) => <Map<String, dynamic>>[]);
      final mutedList = await mutedGroupsService.getUserMutedGroups(uid).catchError((_) => <Map<String, dynamic>>[]);
      final groups = groupsList.map((e) => ChatConversation.fromJson(e)).toList();
      final mutedMap = {
        for (final m in mutedList)
          (m['groupId'] ?? '').toString(): (m['notificationType'] ?? '').toString()
      };
      ref.read(chatProvider.notifier).setGroups(groups);
      ref.read(chatProvider.notifier).setMutedGroups(mutedMap);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';
    final groups = ref.watch(chatProvider.select((s) => s.groups));
    final mutedGroups = ref.watch(chatProvider.select((s) => s.mutedGroups));

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
                const SizedBox(height: 16),
                Text('No groups yet',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Create a group or join one using an invite code',
                    textAlign: TextAlign.center,
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
        itemBuilder: (ctx, i) {
          final g = groups[i];
          final isGroupMuted = mutedGroups[g.id] == 'muted';
          return _ChatTile(
            conv: g,
            isGroup: true,
            isOnline: false,
            isMuted: isGroupMuted,
            currentUserId: uid,
          );
        },
      ),
    );
  }
}

// ── Channel Chat List ──────────────────────────────────────────────────────────
class _ChannelChatList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ChannelChatList> createState() => _ChannelChatListState();
}

class _ChannelChatListState extends ConsumerState<_ChannelChatList> {
  List<Map<String, dynamic>> _channels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchChannels();
  }

  Future<void> _fetchChannels() async {
    try {
      final res = await dioClient.get(AppEndpoints.myChannels);
      final data = res.data['data'];
      List<Map<String, dynamic>> channels = [];
      if (data is Map && data['channels'] is List) {
        channels = List<Map<String, dynamic>>.from(data['channels'] as List);
      } else if (data is List) {
        channels = List<Map<String, dynamic>>.from(data);
      }
      if (mounted) {
        setState(() {
          _channels = channels;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _fetchChannels();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final uid = ref.watch(authProvider).uid ?? '';

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    if (_channels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.campaign_outlined, size: 64, color: c.textTertiary),
                const SizedBox(height: 16),
                Text('No channels yet',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
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
        itemCount: _channels.length,
        itemBuilder: (ctx, i) => _ChannelTile(
          channelData: _channels[i],
          currentUserId: uid,
          onUnreadZeroed: (id) {
            setState(() {
              final idx = _channels.indexWhere((ch) => ch['id'].toString() == id);
              if (idx != -1) {
                _channels[idx] = {..._channels[idx], 'unread_count': 0};
              }
            });
          },
        ),
      ),
    );
  }
}

// ── ChannelTile ────────────────────────────────────────────────────────────────
// Mirrors ChannelListScreen's ChannelItem from the RN project
class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> channelData;
  final String currentUserId;
  final void Function(String id)? onUnreadZeroed;

  const _ChannelTile({
    required this.channelData,
    required this.currentUserId,
    this.onUnreadZeroed,
  });

  String _getLastMessageText() {
    final ch = channelData;
    if (ch['last_message_at'] == null) return 'No updates yet';
    final type = ch['last_message_type']?.toString();
    if (type == 'image') return '📷 Photo';
    if (type == 'image_album') return '📷 Album';
    if (type == 'video') return '🎥 Video';
    if (type == 'voice') return '🎤 Voice Message';
    if (type == 'audio') return '🎵 Audio';
    if (type == 'file') return '📄 File';
    if (type == 'giphy_gif') return '🎞 GIF';
    if (type == 'giphy_sticker') return '🎭 Sticker';
    if (type == 'poll') return '📊 Poll';
    return ch['last_message']?.toString() ?? 'New update';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ch = channelData;
    final isBanned = ch['is_banned'] == 1 || ch['is_banned'] == true;
    final isMuted = ch['is_muted'] == 1 || ch['is_muted'] == true;
    final isVerified = ch['is_verified'] == 1 || ch['is_verified'] == true;
    final hasUnread = (ch['unread_count'] as num? ?? 0) > 0;
    final unreadCount = (ch['unread_count'] as num?)?.toInt() ?? 0;

    final timeStr = ch['last_message_at'] != null
        ? _formatChatListTime(
            DateTime.tryParse(ch['last_message_at'].toString()) ?? DateTime.now())
        : null;

    return Material(
      color: isBanned ? c.background.withValues(alpha: 0.75) : c.background,
      child: InkWell(
        onTap: () {
          onUnreadZeroed?.call(ch['id'].toString());
          context.push('/channel/${ch['id']}');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: c.border.withValues(alpha: 0.15), width: 0.5),
            ),
          ),
          child: Row(children: [
            // Avatar
            Stack(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isBanned ? const Color(0xFF999999) : c.primary,
                backgroundImage: ch['icon'] != null
                    ? CachedNetworkImageProvider(ch['icon'].toString())
                    : null,
                child: ch['icon'] == null
                    ? isBanned
                        ? const Icon(Icons.gavel, color: Colors.white, size: 24)
                        : Text(
                            ((ch['name']?.toString() ?? 'C').isNotEmpty
                                    ? (ch['name']?.toString() ?? 'C')[0]
                                    : 'C')
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 22,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                color: Colors.white))
                    : null,
              ),
              if (isBanned)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.background, width: 2),
                    ),
                    child: const Icon(Icons.gavel, size: 11, color: Colors.white),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: Row(children: [
                        Flexible(
                          child: Text(
                            ch['name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              color: isBanned ? c.textSecondary : c.text,
                            ),
                          ),
                        ),
                        if (!isBanned && isVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(Icons.verified,
                                size: 16, color: const Color(0xFF0751DF)),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    if (isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.gavel, size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          const Text('BANNED',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                      )
                    else if (timeStr != null)
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          color: hasUnread ? c.primary : c.textSecondary,
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: Text(
                        isBanned
                            ? 'This channel has been banned by the platform'
                            : _getLastMessageText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          color: isBanned ? const Color(0xFFFF3B30) : c.textSecondary,
                          fontStyle:
                              isBanned ? FontStyle.italic : FontStyle.normal,
                          fontWeight: hasUnread && !isBanned
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (!isBanned && isMuted)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.notifications_off,
                            size: 14, color: c.textSecondary),
                      ),
                    if (!isBanned && hasUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
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
}

// ── ChatTile ───────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final ChatConversation conv;
  final bool isGroup;
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
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasUnread = conv.unreadCount > 0;
    final isMyMessage = conv.lastMessageSenderId == currentUserId;
    final otherUser = conv.otherUser;
    final iBlockedThem = conv.iBlockedThem;

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
    final isMyReaction = conv.lastReactionUserId == currentUserId;
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

    final timeStr =
        displayTime != null ? _formatChatListTime(displayTime) : '';

    return Material(
      color: c.background,
      child: InkWell(
        onTap: () {
          if (isGroup) {
            context.push('/chat/group/${conv.id}');
          } else {
            context.push('/chat/conversation/${conv.id}', extra: {
              'otherUser': otherUser,
              'status': conv.status,
              'initiatorId': conv.initiatorId,
            });
          }
        },
        onLongPress: onLongPress,
        splashColor: c.border.withValues(alpha: 0.3),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: c.border.withValues(alpha: 0.15), width: 0.5),
            ),
          ),
          child: Row(children: [
            // Avatar
            Stack(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isGroup ? c.primary : c.surface,
                backgroundImage: conv.profilePic != null
                    ? CachedNetworkImageProvider(conv.profilePic!)
                    : null,
                child: conv.profilePic == null
                    ? isGroup
                        ? const Icon(Icons.group,
                            size: 32, color: Colors.white)
                        : Text(
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
            ]),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: Row(children: [
                        Flexible(
                          child: Text(
                            conv.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: c.text,
                            ),
                          ),
                        ),
                        if (!isGroup && otherUser?['is_verified'] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: VerificationBadge(
                              isVerified: true,
                              badge: otherUser?['verification_badge'],
                              size: 16,
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
                        color: hasUnread ? c.primary : c.textSecondary,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (isMyMessage &&
                        !iBlockedThem &&
                        !isLastActivityReaction)
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
                            size: 14, color: const Color(0xFFFF5252)),
                      ),
                    Expanded(
                      child: Text(
                        lastMsgPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
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
                        constraints: const BoxConstraints(
                            minWidth: 24, minHeight: 24),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          conv.unreadCount > 99
                              ? '99+'
                              : conv.unreadCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: const Color(0xFF808080).withValues(alpha: 0.15),
                  width: 0.5),
            ),
          ),
          child: Row(children: [
            Icon(Icons.mail, color: c.primary, size: 22),
            const SizedBox(width: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints:
                  const BoxConstraints(minWidth: 20, minHeight: 20),
              decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 22, color: c.textSecondary),
          ]),
        ),
      ),
    );
  }
}

// ── Time formatter ─────────────────────────────────────────────────────────────
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

// ── Quick actions bottom sheet ─────────────────────────────────────────────────
// Mirrors ChatQuickActionsSheet.jsx: View Profile, Clear Chat, Mute/Unmute,
// Unmatch (if matched), Block/Unblock, Report
void _showQuickActionsSheet(BuildContext context, ChatConversation conv,
    bool isMuted, String currentUserId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _QuickActionsSheet(
      conv: conv,
      isMuted: isMuted,
      currentUserId: currentUserId,
    ),
  );
}

class _QuickActionsSheet extends ConsumerStatefulWidget {
  final ChatConversation conv;
  final bool isMuted;
  final String currentUserId;

  const _QuickActionsSheet({
    required this.conv,
    required this.isMuted,
    required this.currentUserId,
  });

  @override
  ConsumerState<_QuickActionsSheet> createState() => _QuickActionsSheetState();
}

class _QuickActionsSheetState extends ConsumerState<_QuickActionsSheet> {
  bool _isBlocked = false;
  bool _isMatched = false;
  bool _isUnmatching = false;
  bool _loadingStatuses = true;
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _fetchStatuses();
  }

  Future<void> _fetchStatuses() async {
    final otherUserId = widget.conv.otherUserId;
    if (otherUserId == null || widget.currentUserId.isEmpty) {
      if (mounted) setState(() => _loadingStatuses = false);
      return;
    }
    bool blocked = false;
    bool matched = false;

    await Future.wait([
      () async {
        try {
          final res = await dioClient.get(AppEndpoints.checkBlock,
              queryParameters: {
                'blocker_id': widget.currentUserId,
                'blocked_id': otherUserId,
              });
          if (res.data['data'] != null) {
            blocked = res.data['data']['i_blocked_them'] == true;
          }
        } catch (_) {}
      }(),
      () async {
        try {
          final res = await dioClient
              .get(AppEndpoints.profileInteraction(otherUserId));
          if (res.data['data'] != null) {
            matched = res.data['data']['status'] == 'matched';
          }
        } catch (_) {}
      }(),
    ]);

    if (mounted) {
      setState(() {
        _isBlocked = blocked;
        _isMatched = matched;
        _loadingStatuses = false;
      });
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontFamily: 'Outfit')),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _handleBlock() async {
    if (!mounted) return;
    Navigator.pop(context);
    try {
      await dioClient.post(AppEndpoints.blockUser, data: {
        'blocker_id': widget.currentUserId,
        'blocked_id': widget.conv.otherUserId,
      });
      _showToast('User has been blocked');
    } catch (_) {
      _showToast('Failed to block user. Please try again.');
    }
  }

  Future<void> _handleUnblock() async {
    if (!mounted) return;
    Navigator.pop(context);
    try {
      await dioClient.post(AppEndpoints.unblockUser, data: {
        'blocker_id': widget.currentUserId,
        'blocked_id': widget.conv.otherUserId,
      });
      _showToast('User has been unblocked');
    } catch (_) {
      _showToast('Failed to unblock user. Please try again.');
    }
  }

  Future<void> _handleMute(String duration) async {
    Navigator.pop(context);
    try {
      await mutedChatsService.muteChat(
        userId: widget.currentUserId,
        mutedUserId: widget.conv.otherUserId!,
        conversationId: widget.conv.id,
        muteDuration: duration,
      );
      // Update muted state in provider
      final current = Set<String>.from(
          ref.read(chatProvider).mutedChats);
      current.add(widget.conv.otherUserId!);
      ref.read(chatProvider.notifier).setMutedChats(current);
      _showToast('Notifications muted');
    } catch (_) {
      _showToast('Failed to mute chat. Please try again.');
    }
  }

  Future<void> _handleUnmute() async {
    Navigator.pop(context);
    try {
      await mutedChatsService.unmuteChat(
        userId: widget.currentUserId,
        mutedUserId: widget.conv.otherUserId!,
      );
      final current = Set<String>.from(
          ref.read(chatProvider).mutedChats);
      current.remove(widget.conv.otherUserId!);
      ref.read(chatProvider.notifier).setMutedChats(current);
      _showToast('Notifications unmuted');
    } catch (_) {
      _showToast('Failed to unmute chat. Please try again.');
    }
  }

  Future<void> _handleUnmatch() async {
    setState(() => _isUnmatching = true);
    try {
      await dioClient.post(AppEndpoints.unmatch,
          data: {'targetUserId': widget.conv.otherUserId});
      ref
          .read(chatProvider.notifier)
          .deleteConversation(widget.conv.id, deleteType: 'for_everyone');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _showToast('Failed to unmatch. Please try again.');
    } finally {
      if (mounted) setState(() => _isUnmatching = false);
    }
  }

  void _showMuteDurationPicker() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text('Mute notifications for',
              style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: c.text)),
          const SizedBox(height: 8),
          _MuteDurationTile(
            label: '8 hours',
            onTap: () {
              Navigator.pop(ctx);
              _handleMute('8_hours');
            },
          ),
          _MuteDurationTile(
            label: '1 week',
            onTap: () {
              Navigator.pop(ctx);
              _handleMute('1_week');
            },
          ),
          _MuteDurationTile(
            label: 'Always',
            onTap: () {
              Navigator.pop(ctx);
              _handleMute('always');
            },
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ]),
      ),
    );
  }

  void _showClearChatDialog() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Clear Chat',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to clear all messages in this chat?',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: const Color(0xFF3B82F6),
                    fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ref.read(chatProvider.notifier).deleteConversation(
                  widget.conv.id,
                  deleteType: 'for_me');
            },
            child: const Text('Delete for Me',
                style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ref.read(chatProvider.notifier).deleteConversation(
                  widget.conv.id,
                  deleteType: 'for_everyone');
            },
            child: const Text('Delete for Everyone',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showUnmatchDialog() {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Unmatch',
            style: TextStyle(
                color: c.text,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600)),
        content: Text(
            'If you unmatch, the chat conversation will be deleted and you can no longer message each other.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: const Color(0xFF3B82F6),
                    fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: _isUnmatching
                ? null
                : () {
                    Navigator.pop(ctx);
                    _handleUnmatch();
                  },
            child: _isUnmatching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Unmatch',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final otherUser = widget.conv.otherUser;
    final otherUserName =
        otherUser?['name'] ?? otherUser?['username'] ?? widget.conv.name;
    final otherUserUsername = otherUser?['username']?.toString();
    final isVerified = otherUser?['is_verified'] == true;
    final verificationBadge = otherUser?['verification_badge'];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 4),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
                color: c.textTertiary,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header with avatar + name
          if (otherUser != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c.surface,
                  backgroundImage: widget.conv.profilePic != null
                      ? CachedNetworkImageProvider(widget.conv.profilePic!)
                      : null,
                  child: widget.conv.profilePic == null
                      ? Text(
                          (widget.conv.name.isNotEmpty
                                  ? widget.conv.name[0]
                                  : '?')
                              .toUpperCase(),
                          style: TextStyle(
                              color: c.text,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              otherUserName.toString(),
                              style: TextStyle(
                                  fontSize: 17,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: c.text),
                            ),
                          ),
                          if (isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: VerificationBadge(
                                isVerified: true,
                                badge: verificationBadge,
                                size: 18,
                              ),
                            ),
                        ]),
                        if (otherUserUsername != null)
                          Text(
                            '@$otherUserUsername',
                            style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Outfit',
                                color: c.textSecondary),
                          ),
                      ]),
                ),
              ]),
            ),
          Divider(height: 1, color: c.border),
          // Options
          _SheetOption(
            icon: Icons.person,
            label: 'View Profile',
            onTap: () {
              final otherId = widget.conv.otherUserId;
              Navigator.pop(context);
              if (otherId != null) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (context.mounted) context.push('/profile/$otherId');
                });
              }
            },
          ),
          _SheetOption(
            icon: Icons.delete_sweep,
            label: 'Clear Chat',
            onTap: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300),
                  _showClearChatDialog);
            },
          ),
          _SheetOption(
            icon: _isMuted
                ? Icons.notifications_active
                : Icons.notifications_off,
            label: _isMuted ? 'Unmute' : 'Mute',
            onTap: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_isMuted) {
                  _handleUnmute();
                } else {
                  _showMuteDurationPicker();
                }
              });
            },
          ),
          if (!_loadingStatuses && _isMatched)
            _SheetOption(
              icon: Icons.heart_broken,
              label: 'Unmatch',
              onTap: () {
                Navigator.pop(context);
                Future.delayed(
                    const Duration(milliseconds: 300), _showUnmatchDialog);
              },
            ),
          _SheetOption(
            icon: _isBlocked ? Icons.check_circle : Icons.block,
            label: _isBlocked ? 'Unblock' : 'Block',
            onTap: _isBlocked ? _handleUnblock : _handleBlock,
          ),
          _SheetOption(
            icon: Icons.flag,
            label: 'Report',
            isDanger: true,
            isLast: true,
            onTap: () {
              final reportExtra = {
                'entityType': 'user',
                'entityId': widget.conv.otherUserId,
                'entityDetails': {
                  'username': otherUser?['username'],
                  'name': otherUser?['name'],
                },
                'reportSource': 'chat_quick_actions',
                'reportSourceId': 5,
              };
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) context.push('/report', extra: reportExtra);
              });
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;
  final bool isLast;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconBgColor = isDanger
        ? const Color(0xFFFF3B30).withValues(alpha: 0.12)
        : c.background;
    final iconColor = isDanger ? const Color(0xFFFF3B30) : c.text;
    final textColor = isDanger ? const Color(0xFFFF3B30) : c.text;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: c.border.withValues(alpha: 0.5),
                      width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Outfit',
                    color: textColor)),
          ),
          Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
        ]),
      ),
    );
  }
}

class _MuteDurationTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MuteDurationTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      title: Text(label,
          style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              color: c.text)),
      onTap: onTap,
    );
  }
}
