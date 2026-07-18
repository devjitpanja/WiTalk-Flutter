import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';

final _postDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, postId) async {
  final res = await dioClient.get('/v1/posts/$postId');
  return res.data['data'] ?? {};
});

final _commentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, postId) async {
  final res = await dioClient.get('/v1/posts/$postId/comments');
  return res.data['data'] ?? [];
});

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});
  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await dioClient.post('/v1/posts/${widget.postId}/comments', data: {'content': text});
      _commentCtrl.clear();
      ref.refresh(_commentsProvider(widget.postId));
    } catch (_) {} finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(_postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(_commentsProvider(widget.postId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Post', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: Column(children: [
        Expanded(child: postAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
          data: (post) => ListView(children: [
            PostCard(post: post),
            const Divider(color: AppColors.border),
            Padding(padding: const EdgeInsets.all(16), child: Text('Comments', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Outfit'))),
            commentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)),
              error: (_, __) => const SizedBox(),
              data: (comments) => ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: comments.length,
                itemBuilder: (_, i) => _CommentTile(comment: comments[i])),
            ),
          ]),
        )),
        _buildCommentInput(),
      ]),
    );
  }

  Widget _buildCommentInput() => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
    child: Row(children: [
      Expanded(child: TextField(controller: _commentCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
        decoration: InputDecoration(hintText: 'Write a comment...', hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
          filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
      const SizedBox(width: 8),
      GestureDetector(onTap: _submitComment,
        child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.primaryButton, shape: BoxShape.circle),
          child: _sending ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 18))),
    ]),
  );
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});
  @override
  Widget build(BuildContext context) {
    final user = comment['user'] as Map<String, dynamic>?;
    final name = user?['name'] ?? 'Unknown';
    final pic = user?['profile_pic'];
    final timeStr = comment['created_at'] != null ? timeago.format(DateTime.tryParse(comment['created_at']) ?? DateTime.now()) : '';
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 16, backgroundColor: AppColors.border, backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null, child: pic == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)) : null),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Outfit')), const SizedBox(width: 8), Text(timeStr, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'Outfit'))]),
        const SizedBox(height: 2),
        Text(comment['content'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
      ])),
    ]));
  }
}
