import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class MeritScreen extends ConsumerWidget {
  const MeritScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(FutureProvider.autoDispose((ref) async {
      final res = await dioClient.get('/v1/merit/me');
      return res.data['data'] ?? {};
    }));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Merit', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed', style: TextStyle(color: Colors.white70))),
        data: (d) {
          final score = d['merit_score'] ?? 0;
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⭐', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('$score', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
            const Text('Merit Score', style: TextStyle(color: AppColors.textTertiary, fontSize: 16, fontFamily: 'Outfit')),
          ]));
        },
      ),
    );
  }
}
