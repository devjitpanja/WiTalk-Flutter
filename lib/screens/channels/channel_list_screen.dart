import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _myChannelsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/channels/my');
  return res.data['data'] ?? [];
});

class ChannelListScreen extends ConsumerWidget {
  const ChannelListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myChannelsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Channels', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.explore_outlined, color: Colors.white), onPressed: () => context.push('/explore-channels'))]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (channels) => channels.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('📢', style: TextStyle(fontSize: 48)), const SizedBox(height: 12),
                const Text('No channels yet', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.push('/explore-channels'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Explore Channels', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600))),
              ]))
            : ListView.builder(itemCount: channels.length, itemBuilder: (_, i) {
                final c = channels[i] as Map<String, dynamic>;
                final name = c['name'] as String? ?? '';
                final pic = c['image'] as String?;
                final subs = c['subscriber_count'] ?? 0;
                final id = c['id'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(radius: 24, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? const Icon(Icons.campaign, color: Colors.white, size: 20) : null),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  subtitle: Text('$subs subscribers', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                  onTap: () => context.push('/channel/$id'),
                );
              }),
      ),
    );
  }
}
