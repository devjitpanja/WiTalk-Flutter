import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _discoverProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/users/discover');
  return res.data['data'] ?? [];
});

class DiscoverPeopleScreen extends ConsumerWidget {
  const DiscoverPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_discoverProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1017),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        title: const Text('Discover People', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF5B51F4))),
        error: (_, __) => const Center(child: Text('Failed', style: TextStyle(color: Colors.white70))),
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i] as Map<String, dynamic>;
            final name = u['name'] as String? ?? '';
            final pic = u['profile_pic'] as String?;
            final username = u['username'] as String?;
            final id = u['id'] as String? ?? '';
            return ListTile(
              leading: CircleAvatar(radius: 24, backgroundColor: const Color(0xFF38383A),
                backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)) : null),
              title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              subtitle: username != null ? Text('@$username', style: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'Outfit', fontSize: 12)) : null,
              trailing: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B51F4), minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Follow', style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
              ),
              onTap: () => context.push('/user/$id'),
            );
          },
        ),
      ),
    );
  }
}
