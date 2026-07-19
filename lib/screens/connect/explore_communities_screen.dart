import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';

final _communitiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  final res = await dioClient.get('/v1/groups/public/list', queryParameters: {'userId': uid, 'limit': 20, 'offset': 0});
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['groups'] as List?) ?? [];
  return [];
});

class ExploreCommunitiesScreen extends ConsumerWidget {
  const ExploreCommunitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_communitiesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Communities', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed', style: TextStyle(color: Colors.white70))),
        data: (comms) => ListView.builder(itemCount: comms.length, itemBuilder: (_, i) {
          final c = comms[i] as Map<String, dynamic>; final name = c['name'] ?? ''; final pic = c['image']; final members = c['member_count'] ?? 0; final id = c['id'] ?? '';
          return ListTile(leading: CircleAvatar(radius: 24, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white)) : null),
            title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            subtitle: Text('$members members', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
            trailing: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Join', style: TextStyle(fontFamily: 'Outfit', fontSize: 13))),
            onTap: () => context.push('/community-info/$id'));
        }),
      ),
    );
  }
}