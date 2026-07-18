import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

final _miniFeedProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await dioClient.get('/v1/posts/mini-feed');
  return res.data['data'] ?? [];
});

class MiniScreen extends ConsumerWidget {
  const MiniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_miniFeedProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white70))),
        data: (posts) => PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: posts.length,
          itemBuilder: (_, i) => _MiniItem(post: posts[i] as Map<String, dynamic>),
        ),
      ),
    );
  }
}

class _MiniItem extends StatefulWidget {
  final Map<String, dynamic> post;
  const _MiniItem({required this.post});
  @override
  State<_MiniItem> createState() => _MiniItemState();
}

class _MiniItemState extends State<_MiniItem> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    final media = widget.post['media'] as List?;
    final videoUrl = media?.firstOrNull?['url'] as String?;
    if (videoUrl != null) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _ctrl!.play();
            _ctrl!.setLooping(true);
          }
        });
    }
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = widget.post['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? '';
    final pic = user?['profile_pic'] as String?;
    final content = widget.post['content'] as String? ?? '';
    final likes = widget.post['likes'] ?? 0;
    final comments = widget.post['comments'] ?? 0;

    return Stack(fit: StackFit.expand, children: [
      _ctrl != null && _ctrl!.value.isInitialized
          ? GestureDetector(
              onTap: () => _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play(),
              child: VideoPlayer(_ctrl!))
          : Container(color: Colors.black87, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      Positioned(bottom: 80, left: 16, right: 80, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.border,
            backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12)) : null),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Outfit', shadows: [Shadow(blurRadius: 8)])),
        ]),
        if (content.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(content, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', shadows: [Shadow(blurRadius: 8)]), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ])),
      Positioned(right: 12, bottom: 100, child: Column(children: [
        const Icon(Icons.favorite_border, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text('$likes', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Outfit')),
        const SizedBox(height: 16),
        const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text('$comments', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Outfit')),
      ])),
    ]);
  }
}
