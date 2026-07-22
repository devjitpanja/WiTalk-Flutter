import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../services/post_view_tracking_service.dart';
import '../../services/post_feedback_service.dart';
import '../../widgets/common/post_card.dart';
import '../../widgets/common/witalk_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();
  bool _headerVisible = true;
  double _lastScrollY = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final y = _scrollCtrl.offset;
    final diff = y - _lastScrollY;
    _lastScrollY = y;

    // Toggle header visibility on scroll
    if (diff > 5 && _headerVisible) setState(() => _headerVisible = false);
    if (diff < -5 && !_headerVisible) setState(() => _headerVisible = true);

    // Infinite scroll pagination threshold (400px before end)
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  void _onLikeUpdate(String postId, bool isLiked, int count) {
    ref.read(feedNotifierProvider.notifier).updateLike(postId, isLiked, count);
  }

  void _onCommentUpdate(String postId, int count) {
    ref.read(feedNotifierProvider.notifier).updateComments(postId, count);
  }

  void _onShowMoreMenu(String postId, String userId, Map<String, dynamic> extra) {
    final c = context.colors;
    final currentUserId = ref.read(authProvider).uid ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.bookmark_border, color: c.text),
          title: Text('Save post', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () {
            Navigator.pop(context);
            if (currentUserId.isNotEmpty) {
              postFeedbackService.sendSaveFeedback(userId: currentUserId, postId: postId);
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.remove_circle_outline, color: c.text),
          title: Text('Not interested', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () {
            Navigator.pop(context);
            if (currentUserId.isNotEmpty) {
              postFeedbackService.sendNotInterestedFeedback(userId: currentUserId, postId: postId);
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.visibility_off_outlined, color: c.text),
          title: Text('Hide post', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () {
            Navigator.pop(context);
            if (currentUserId.isNotEmpty) {
              postFeedbackService.sendHidePostFeedback(userId: currentUserId, postId: postId);
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.flag_outlined, color: c.text),
          title: Text('Report', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () {
            Navigator.pop(context);
            context.push('/report/post/$postId');
          },
        ),
        ListTile(
          leading: Icon(Icons.block, color: c.text),
          title: Text('Block user', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feedState = ref.watch(feedNotifierProvider);
    final currentUserId = ref.watch(authProvider).uid;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          AnimatedSlide(
            offset: _headerVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 200),
            child: _buildHeader(),
          ),
          Expanded(
            child: _buildBody(feedState, currentUserId, c),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody(FeedState state, String? currentUserId, ThemeColors c) {
    if (state.isLoading && state.posts.isEmpty) {
      return _buildSkeleton(c);
    }

    if (state.error != null && state.posts.isEmpty) {
      return _buildError(state.error!, c);
    }

    if (state.posts.isEmpty) {
      return _buildEmpty(c);
    }

    return RefreshIndicator(
      color: c.primaryButton,
      backgroundColor: c.surface,
      onRefresh: () async {
        await ref.read(feedNotifierProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount: state.posts.length + (state.isFetchingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == state.posts.length) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.primaryButton),
              ),
            );
          }

          final post = state.posts[i];
          final postId = post['id'].toString();

          // Start tracking view duration & metrics
          if (currentUserId != null && currentUserId.isNotEmpty) {
            postViewTrackingService.startTracking(
              postId: postId,
              userId: currentUserId,
              screenType: 'feed',
            );
            postFeedbackService.startViewTracking(postId);
          }

          return PostCard(
            post: post,
            currentUserId: currentUserId,
            onLikeUpdate: _onLikeUpdate,
            onCommentUpdate: _onCommentUpdate,
            onShowMoreMenu: _onShowMoreMenu,
          );
        },
      ),
    );
  }

  Widget _buildHeader() => const WiTalkHeader(
        title: 'WiTalk',
        showBorder: true,
        showNotifications: true,
      );

  Widget _buildSkeleton(ThemeColors c) => ListView.builder(
        itemCount: 4,
        itemBuilder: (context2, idx) => Shimmer.fromColors(
          baseColor: c.surface,
          highlightColor: c.border,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            height: 300,
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _buildError(String errorMsg, ThemeColors c) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off, color: c.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text('Could not load feed', style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMsg,
              style: TextStyle(color: c.textTertiary, fontSize: 12, fontFamily: 'Outfit'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.read(feedNotifierProvider.notifier).fetchInitialFeed();
            },
            child: Text('Retry', style: TextStyle(color: c.primaryButton, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _buildEmpty(ThemeColors c) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('👋', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text('Your feed is empty', style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Follow people to see their posts here', style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push('/discover-people'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primaryButton,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Discover People', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
