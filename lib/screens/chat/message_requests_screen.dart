import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _requestsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/chat/requests');
  return res.data['data'] ?? [];
});

class MessageRequestsScreen extends ConsumerWidget {
  const MessageRequestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_requestsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Message Requests', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (requests) => requests.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('💬', style: TextStyle(fontSize: 48)), SizedBox(height: 12),
                Text('No message requests', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              ]))
            : ListView.builder(
                itemCount: requests.length,
                itemBuilder: (_, i) => _RequestTile(request: requests[i] as Map<String, dynamic>, onAction: () => ref.refresh(_requestsProvider)),
              ),
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAction;
  const _RequestTile({required this.request, required this.onAction});
  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _processing = false;

  Future<void> _respond(bool accept) async {
    setState(() => _processing = true);
    try {
      final id = widget.request['id'] as String? ?? '';
      await dioClient.post('/v1/chat/requests/$id/${accept ? 'accept' : 'decline'}');
      widget.onAction();
    } catch (_) { if (mounted) setState(() => _processing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.request['from_user'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? '';
    final pic = user['profile_pic'] as String?;
    final preview = widget.request['preview'] as String? ?? 'Wants to message you';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(radius: 24, backgroundColor: AppColors.border,
        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
        child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)) : null),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      subtitle: Text(preview, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _processing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryButton))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: () => _respond(false), child: const Text('Decline', style: TextStyle(color: AppColors.error, fontFamily: 'Outfit', fontWeight: FontWeight.w600))),
              ElevatedButton(onPressed: () => _respond(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(70, 32), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Accept', style: TextStyle(fontFamily: 'Outfit', fontSize: 13))),
            ]),
    );
  }
}
