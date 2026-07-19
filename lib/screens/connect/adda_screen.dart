import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/witalk_header.dart';

final _roomsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/audio-rooms');
  final data = res.data['data'];
  if (data is List) return data;
  if (data is Map) return (data['rooms'] as List?) ?? [];
  return [];
});

class AddaScreen extends ConsumerStatefulWidget {
  const AddaScreen({super.key});

  @override
  ConsumerState<AddaScreen> createState() => _AddaScreenState();
}

class _AddaScreenState extends ConsumerState<AddaScreen> with TickerProviderStateMixin {
  late final AnimationController _ring1Ctrl;
  late final AnimationController _ring2Ctrl;
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Opacity;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Opacity;

  @override
  void initState() {
    super.initState();

    _ring1Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _ring1Scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );
    _ring1Opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ring1Ctrl, curve: Curves.easeOut),
    );

    _ring2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _ring2Scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );
    _ring2Opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ring2Ctrl, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ring2Ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ring1Ctrl.dispose();
    _ring2Ctrl.dispose();
    super.dispose();
  }

  Widget _buildMicButton() {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push('/create-audio-room'),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ring1Ctrl,
              builder: (context, child) => Opacity(
                opacity: _ring1Opacity.value,
                child: Transform.scale(
                  scale: _ring1Scale.value,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.text, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _ring2Ctrl,
              builder: (context, child) => Opacity(
                opacity: _ring2Opacity.value,
                child: Transform.scale(
                  scale: _ring2Scale.value,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.text, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            Image.asset(
              'assets/icons/mic.png',
              width: 24,
              height: 24,
              color: c.text,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final roomsAsync = ref.watch(_roomsProvider);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Column(children: [
        WiTalkHeader(
          title: 'WiTalk',
          showBorder: false,
          showNotifications: true,
          leadingAction: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildMicButton(),
          ),
        ),
        Expanded(child: roomsAsync.when(
          loading: () => _skeleton(c),
          error: (err, stack) => Center(child: Text('Failed to load', style: TextStyle(color: c.textTertiary))),
          data: (rooms) => RefreshIndicator(
            color: c.primaryButton,
            backgroundColor: c.surface,
            onRefresh: () => ref.refresh(_roomsProvider.future),
            child: rooms.isEmpty ? _empty(c) : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              itemBuilder: (_, i) => _RoomCard(room: rooms[i] as Map<String, dynamic>),
            ),
          ),
        )),
      ])),
    );
  }

  Widget _skeleton(ThemeColors c) => ListView.builder(
    itemCount: 4,
    itemBuilder: (ctx, idx) => Shimmer.fromColors(
      baseColor: c.surface,
      highlightColor: c.border,
      child: Container(margin: const EdgeInsets.fromLTRB(12, 6, 12, 6), height: 100, decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16))),
    ),
  );

  Widget _empty(ThemeColors c) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('🎙️', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 12),
    Text('No live rooms right now', style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Text('Start a room to begin talking', style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
  ]));
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
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
          Text(title, style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          const SizedBox(height: 8),
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: c.border,
              backgroundImage: hostPic != null ? CachedNetworkImageProvider(hostPic) : null,
              child: hostPic == null ? Text(hostName.isNotEmpty ? hostName[0].toUpperCase() : '?', style: TextStyle(color: c.text, fontSize: 10)) : null),
            const SizedBox(width: 8),
            Text(hostName, style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
            const Spacer(),
            Icon(Icons.people_outline, color: c.textTertiary, size: 16),
            const SizedBox(width: 4),
            Text('$participants', style: TextStyle(color: c.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
          ]),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, children: tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.primaryButton.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('#$t', style: TextStyle(color: c.primaryButton, fontSize: 11, fontFamily: 'Outfit')),
              )).toList()),
            ),
        ]),
      ),
    );
  }
}
