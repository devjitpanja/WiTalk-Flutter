import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';

class VisitorsScreen extends ConsumerWidget {
  const VisitorsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(FutureProvider.autoDispose((ref) async {
      final uid = ref.watch(authProvider).uid ?? '';
      final res = await dioClient.get('/v1/profile-visits/$uid', queryParameters: {'page': 1, 'limit': 30});
      final data = res.data['data'];
      if (data is List) return data;
      if (data is Map) return (data['visits'] as List?) ?? [];
      return [];
    }));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Visitors', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (visitors) => visitors.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('👁️', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
                Text('No visitors yet', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('People who view your profile appear here', style: TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
              ]))
            : ListView.builder(
                itemCount: visitors.length,
                itemBuilder: (_, i) {
                  final v = visitors[i] as Map<String, dynamic>;
                  final user = v['user'] as Map<String, dynamic>? ?? v;
                  final name = user['name'] as String? ?? '';
                  final pic = user['profile_pic'] as String?;
                  final id = user['id'] as String? ?? '';
                  final visitedAt = v['visited_at'] as String?;
                  final time = visitedAt != null ? timeago.format(DateTime.tryParse(visitedAt) ?? DateTime.now()) : '';
                  return ListTile(
                    leading: CircleAvatar(radius: 22, backgroundColor: AppColors.border,
                      backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                      child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)) : null),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    trailing: Text(time, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                    onTap: () => context.push('/user/$id'),
                  );
                },
              ),
      ),
    );
  }
}
