import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';

class PostViewScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostViewScreen({super.key, required this.postId});
  @override
  ConsumerState<PostViewScreen> createState() => _PostViewScreenState();
}

class _PostViewScreenState extends ConsumerState<PostViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop())),
      body: const Center(child: Text('Post View', style: TextStyle(color: Colors.white70))),
    );
  }
}
