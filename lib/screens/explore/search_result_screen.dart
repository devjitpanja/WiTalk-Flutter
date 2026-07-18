import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';

class SearchResultScreen extends ConsumerWidget {
  final String query;
  const SearchResultScreen({super.key, required this.query});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(FutureProvider.autoDispose((ref) async {
      final res = await dioClient.get('/v1/search?q=\${Uri.encodeComponent(query)}&type=posts'); return res.data['data'] ?? [];
    }));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: Text('#\$query', style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('No results', style: TextStyle(color: Colors.white70))),
        data: (posts) => ListView.builder(itemCount: posts.length, itemBuilder: (_, i) => PostCard(post: posts[i] as Map<String, dynamic>)),
      ),
    );
  }
}