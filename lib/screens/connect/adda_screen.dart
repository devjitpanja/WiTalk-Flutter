import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _roomsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/audio-rooms');
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['rooms'] as List?) ?? [];
  return [];
});

class AddaScreen extends ConsumerWidget {
  const AddaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(_roomsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [
          const Expanded(child: Text('Adda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit'))),
          ElevatedButton.icon(
            onPressed: () => context.push('/create-audio-room'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Start', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ])),
        Expanded(child: roomsAsync.when(
          loading: () => _skeleton(),
          error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
          data: (rooms) => RefreshIndicator(
            color: AppColors.primaryButton,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.refresh(_roomsProvider.future),
            child: rooms.isEmpty ? _empty() : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              itemBuilder: (_, i) => _RoomCard(room: rooms[i] as Map<String, dynamic>),
            ),
          ),
        )),
      ])),
    );
  }

  Widget _skeleton() => ListView.builder(
    itemCount: 4,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: Container(margin: const EdgeInsets.fromLTRB(12, 6, 12, 6), height: 100, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16))),
    ),
  );

  Widget _empty() => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text('🎙️', style: TextStyle(fontSize: 56)),
    SizedBox(height: 12),
    Text('No live rooms right now', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
    SizedBox(height: 8),
    Text('Start a room to begin talking', style: TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
  ]));
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final title = room['title']?.toString() ?? 'Live Room';
    final host = room['host'] as Map<String, dynamic>?;
    final hostName = host?['name']?.toString() ?? '';
    final hostPic = host?['profile_pic']?.toString();
    final participants = room['participant_count'] ?? 0;
    final id = room['id']?.toString() ?? '';
    final tags = (room['tags'] as List? ?? []).map((t) => t.toString()).toList();

    return GestureDetector(
      onTap: () => context.push('/live-audio/$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: Colors.white, size: 8),
              SizedBox(width: 4),
              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          const SizedBox(height: 8),
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: AppColors.border,
              backgroundImage: hostPic != null ? CachedNetworkImageProvider(hostPic) : null,
              child: hostPic == null ? Text(hostName.isNotEmpty ? hostName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 10)) : null),
            const SizedBox(width: 8),
            Text(hostName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
            const Spacer(),
            const Icon(Icons.people_outline, color: AppColors.textTertiary, size: 16),
            const SizedBox(width: 4),
            Text('$participants', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
          ]),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, children: tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Color(0x265B51F4), borderRadius: BorderRadius.circular(12)),
                child: Text('#$t', style: const TextStyle(color: AppColors.primaryButton, fontSize: 11, fontFamily: 'Outfit')),
              )).toList()),
            ),
        ]),
      ),
    );
  }
}
