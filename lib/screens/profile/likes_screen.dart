import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';
import '../../providers/auth_provider.dart';

class LikesScreen extends ConsumerWidget {
  const LikesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(FutureProvider.autoDispose((ref) async {
      final uid = ref.watch(authProvider).uid ?? '';
      final res = await dioClient.get('/v1/post-saves/$uid', queryParameters: {'page': 1, 'limit': 20});
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) return (data['posts'] as List?) ?? [];
      return [];
    }));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Liked Posts', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (posts) => posts.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('❤️', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
                Text('No liked posts yet', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              ]))
            : ListView.builder(itemCount: posts.length, itemBuilder: (_, i) => PostCard(post: posts[i] as Map<String, dynamic>)),
      ),
    );
  }
}
