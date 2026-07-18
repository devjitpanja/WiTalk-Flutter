import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _chatsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/chat/conversations');
  return res.data['data'] ?? [];
});

final _groupsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/chat/groups');
  return res.data['data'] ?? [];
});

final _channelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/channels/my');
  return res.data['data'] ?? [];
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primaryButton,
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

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      const Text('Chats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit')),
      const Spacer(),
      IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => context.push('/search')),
      IconButton(
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        onPressed: () => _showNewChatMenu(context),
      ),
    ]),
  );

  void _showNewChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        ListTile(leading: const Icon(Icons.group_add, color: Colors.white), title: const Text('New Group', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')), onTap: () { Navigator.pop(context); context.push('/chat/create-group'); }),
        ListTile(leading: const Icon(Icons.campaign_outlined, color: Colors.white), title: const Text('New Channel', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')), onTap: () { Navigator.pop(context); context.push('/create-channel'); }),
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
    final async = ref.watch(provider as ProviderListenable<AsyncValue<List<dynamic>>>);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
      data: (items) => items.isEmpty
          ? _buildEmpty(type)
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _ChatTile(item: items[i], type: type),
            ),
    );
  }

  Widget _buildEmpty(String type) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(type == 'channel' ? '📢' : type == 'group' ? '👥' : '💬', style: const TextStyle(fontSize: 48)),
    const SizedBox(height: 12),
    Text('No ${type == 'channel' ? 'channels' : type == 'group' ? 'groups' : 'messages'} yet',
      style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
  ]));
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;
  const _ChatTile({required this.item, required this.type});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? item['username'] ?? 'Unknown';
    final pic = item['profile_pic'] ?? item['avatar'] ?? item['image'];
    final lastMsg = item['last_message'] ?? item['lastMessage'] ?? '';
    final unread = item['unread_count'] ?? 0;
    final id = item['id'] ?? item['_id'] ?? '';
    final timeStr = item['updated_at'] != null ? timeago.format(DateTime.tryParse(item['updated_at']) ?? DateTime.now(), allowFromNow: true) : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26, backgroundColor: AppColors.border,
        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
        child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)) : null,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(lastMsg.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 13)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(timeStr, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'Outfit')),
        if (unread > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primaryButton, borderRadius: BorderRadius.circular(10)),
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
