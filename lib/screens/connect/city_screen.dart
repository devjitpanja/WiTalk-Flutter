import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';

class CityScreen extends ConsumerWidget {
  final String cityId;
  const CityScreen({super.key, required this.cityId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(FutureProvider.autoDispose((ref) async {
      final res = await dioClient.get('/v1/cities/$cityId');
      return res.data['data'] ?? {};
    }));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => Scaffold(appBar: AppBar(backgroundColor: AppColors.background, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())), body: const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70)))),
        data: (city) {
          final name = city['name'] as String? ?? '';
          final cover = city['cover_image'] as String?;
          final population = city['population'] ?? 0;
          final posts = (city['recent_posts'] as List? ?? []);
          return CustomScrollView(slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background, expandedHeight: 200, pinned: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
                background: cover != null ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover) : Container(color: AppColors.primaryButton.withOpacity(0.3)),
              ),
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              const Icon(Icons.people_outline, color: AppColors.textTertiary, size: 18),
              const SizedBox(width: 6),
              Text('$population members', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit')),
            ]))),
            SliverList(delegate: SliverChildBuilderDelegate((_, i) => PostCard(post: posts[i] as Map<String, dynamic>), childCount: posts.length)),
          ]);
        },
      ),
    );
  }
}
