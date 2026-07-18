import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _notifProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/notifications');
  return res.data['data'] ?? [];
});

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notifProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Notifications', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
        actions: [TextButton(onPressed: () {}, child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontFamily: 'Outfit')))]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (notifs) => notifs.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('🔔', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('No notifications', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600))]))
            : RefreshIndicator(color: AppColors.primaryButton, backgroundColor: AppColors.surface, onRefresh: () => ref.refresh(_notifProvider.future),
                child: ListView.builder(itemCount: notifs.length, itemBuilder: (_, i) => _NotifTile(notif: notifs[i] as Map<String, dynamic>))),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifTile({required this.notif});
  @override
  Widget build(BuildContext context) {
    final title = notif['title'] ?? '';
    final body = notif['body'] ?? '';
    final pic = notif['actor_profile_pic'];
    final isRead = notif['is_read'] == true;
    final time = notif['created_at'] != null ? timeago.format(DateTime.tryParse(notif['created_at']) ?? DateTime.now()) : '';
    return Container(
      color: isRead ? Colors.transparent : AppColors.primaryButton.withOpacity(0.06),
      child: ListTile(
        leading: CircleAvatar(radius: 22, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? const Icon(Icons.notifications, color: Colors.white, size: 20) : null),
        title: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (body.isNotEmpty) Text(body, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(time, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 11)),
        ]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
