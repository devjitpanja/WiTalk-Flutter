import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';
import '../../providers/auth_provider.dart';

final _forYouProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v2/posts/recommended/$uid', queryParameters: {'page': 1, 'limit': 20});
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['posts'] as List?) ?? [];
  return [];
});

class ForYouScreen extends ConsumerWidget {
  const ForYouScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_forYouProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('For You', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (posts) => CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: () => ref.refresh(_forYouProvider.future)),
            if (posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Nothing here yet', style: TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit'))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => PostCard(post: posts[i] as Map<String, dynamic>),
                  childCount: posts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
