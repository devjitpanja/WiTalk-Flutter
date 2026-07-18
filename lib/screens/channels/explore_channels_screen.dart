import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _exploreChannelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/channels/explore');
  return res.data['data'] ?? [];
});

class ExploreChannelsScreen extends ConsumerWidget {
  const ExploreChannelsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_exploreChannelsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Explore Channels', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => context.push('/create-channel'))]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (channels) => channels.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('📢', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('No channels found', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit'))]))
            : RefreshIndicator(
                color: AppColors.primaryButton, backgroundColor: AppColors.surface,
                onRefresh: () => ref.refresh(_exploreChannelsProvider.future),
                child: ListView.builder(itemCount: channels.length, itemBuilder: (_, i) => _ChannelTile(channel: channels[i] as Map<String, dynamic>)),
              ),
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  final Map<String, dynamic> channel;
  const _ChannelTile({required this.channel});
  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  late bool _subscribed;
  bool _loading = false;

  @override
  void initState() { super.initState(); _subscribed = widget.channel['is_subscribed'] == true; }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      final id = widget.channel['id'] as String? ?? '';
      await dioClient.post('/v1/channels/$id/${_subscribed ? 'unsubscribe' : 'subscribe'}');
      setState(() => _subscribed = !_subscribed);
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.channel['name'] as String? ?? '';
    final pic = widget.channel['image'] as String?;
    final subs = widget.channel['subscriber_count'] ?? 0;
    final id = widget.channel['id'] as String? ?? '';
    return ListTile(
      leading: CircleAvatar(radius: 24, backgroundColor: AppColors.border,
        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
        child: pic == null ? const Icon(Icons.campaign, color: Colors.white, size: 20) : null),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      subtitle: Text('$subs subscribers', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
      trailing: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryButton))
          : OutlinedButton(
              onPressed: _toggle,
              style: OutlinedButton.styleFrom(foregroundColor: _subscribed ? AppColors.textTertiary : AppColors.primaryButton, side: BorderSide(color: _subscribed ? AppColors.border : AppColors.primaryButton), minimumSize: const Size(90, 32), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(_subscribed ? 'Subscribed' : 'Subscribe', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13))),
      onTap: () => context.push('/channel/$id'),
    );
  }
}
