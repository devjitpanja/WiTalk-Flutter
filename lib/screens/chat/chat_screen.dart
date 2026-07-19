import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';

final _chatsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v1/chat/conversations/$uid');
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['conversations'] as List?) ?? [];
  return [];
});

final _groupsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v1/groups/user/$uid');
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['groups'] as List?) ?? [];
  return [];
});

final _channelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/channels/my');
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['channels'] as List?) ?? [];
  return [];
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index != _tabIndex) setState(() => _tabIndex = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(c),
        TabBar(
          controller: _tabCtrl,
          labelColor: c.text,
          unselectedLabelColor: c.textTertiary,
          indicatorColor: c.primaryButton,
          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
          tabs: const [Tab(text: 'All'), Tab(text: 'Private'), Tab(text: 'Groups'), Tab(text: 'Channels')],
        ),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [
            _ChatList(provider: _chatsProvider, type: 'private'),
            _ChatList(provider: _chatsProvider, type: 'private'),
            _ChatList(provider: _groupsProvider, type: 'group'),
            _ChatList(provider: _channelsProvider, type: 'channel'),
          ],
        )),
      ])),
    );
  }

  Widget _buildHeader(ThemeColors c) => Container(
    color: c.background,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Row(children: [
      const SizedBox(width: 40),
      Expanded(
        child: Text(
          'Chats',
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
                    onTap: () => _showNewChatMenu(context, c),
                    child: Icon(Icons.add_circle, size: 25, color: c.primary),
                  )
                : const SizedBox.shrink(),
      ),
    ]),
  );

  void _showNewChatMenu(BuildContext context, ThemeColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        ListTile(
          leading: Icon(Icons.group_add, color: c.text),
          title: Text('New Group', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); context.push('/chat/create-group'); },
        ),
        ListTile(
          leading: Icon(Icons.campaign_outlined, color: c.text),
          title: Text('New Channel', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); context.push('/create-channel'); },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _ChatList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<dynamic>>> provider;
  final String type;
  const _ChatList({required this.provider, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(provider as ProviderListenable<AsyncValue<List<dynamic>>>);
    return async.when(
      loading: () => Center(child: CircularProgressIndicator(color: c.primaryButton)),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: c.textTertiary))),
      data: (items) => items.isEmpty
          ? _buildEmpty(context, type, c)
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _ChatTile(item: items[i], type: type),
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, String type, ThemeColors c) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(type == 'channel' ? '📢' : type == 'group' ? '👥' : '💬', style: const TextStyle(fontSize: 48)),
    const SizedBox(height: 12),
    Text('No ${type == 'channel' ? 'channels' : type == 'group' ? 'groups' : 'messages'} yet',
      style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
  ]));
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;
  const _ChatTile({required this.item, required this.type});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = item['name'] ?? item['username'] ?? 'Unknown';
    final pic = item['profile_pic'] ?? item['avatar'] ?? item['image'];
    final lastMsg = item['last_message'] ?? item['lastMessage'] ?? '';
    final unread = item['unread_count'] ?? 0;
    final id = item['id'] ?? item['_id'] ?? '';
    final timeStr = item['updated_at'] != null ? timeago.format(DateTime.tryParse(item['updated_at']) ?? DateTime.now(), allowFromNow: true) : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26, backgroundColor: c.border,
        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
        child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600)) : null,
      ),
      title: Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(lastMsg.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 13)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(timeStr, style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'Outfit')),
        if (unread > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: c.primaryButton, borderRadius: BorderRadius.circular(10)),
            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
      onTap: () {
        if (type == 'group') context.push('/chat/group/$id');
        else if (type == 'channel') context.push('/channel/$id');
        else context.push('/chat/conversation/$id');
      },
    );
  }
}
