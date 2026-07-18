import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _groupsListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/chat/groups');
  return res.data['data'] ?? [];
});

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_groupsListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Groups', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.group_add_outlined, color: Colors.white), onPressed: () => context.push('/chat/create-group'))]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (groups) => groups.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('👥', style: TextStyle(fontSize: 48)), const SizedBox(height: 12),
                const Text('No groups yet', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.push('/chat/create-group'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Create Group', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600))),
              ]))
            : ListView.builder(
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final g = groups[i] as Map<String, dynamic>;
                  final name = g['name'] as String? ?? '';
                  final pic = g['image'] as String?;
                  final lastMsg = g['last_message'] as String? ?? '';
                  final id = g['id'] as String? ?? '';
                  final time = g['updated_at'] != null ? timeago.format(DateTime.tryParse(g['updated_at']) ?? DateTime.now(), allowFromNow: true) : '';
                  return ListTile(
                    leading: CircleAvatar(radius: 24, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)) : null),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 13)),
                    trailing: Text(time, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'Outfit')),
                    onTap: () => context.push('/chat/group/$id'),
                  );
                },
              ),
      ),
    );
  }
}
