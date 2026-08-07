import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../api/dio_client.dart';
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
    final isOwnPost = currentUserId.isNotEmpty && currentUserId == userId;

    // Initial state from extra passed by PostCard
    bool isSaved = extra['isSaved'] == true;
    bool isSaveLoading = false;
    bool isFollowing = extra['isFollowing'] == true;
    bool isActionLoading = false;
    final userName = (extra['userName'] as String?) ?? 'this user';

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) {
          void closeSheet() => Navigator.of(sheetCtx, rootNavigator: true).pop();

          // ── Save / Unsave ──────────────────────────────────────────────────
          Future<void> toggleSave() async {
            if (isSaveLoading || currentUserId.isEmpty) return;
            setSheetState(() => isSaveLoading = true);
            try {
              final res = await dioClient.post('/v1/post-saves/toggle',
                  data: {'postId': postId, 'userId': currentUserId});
              final action = res.data['action'] as String?;
              final saved = action == 'saved';
              setSheetState(() { isSaved = saved; isSaveLoading = false; });
              // Also send recommendation signal
              if (saved && currentUserId.isNotEmpty) {
                postFeedbackService.sendSaveFeedback(userId: currentUserId, postId: postId);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(saved ? 'Post saved successfully!' : 'Post removed from saved items'),
                ));
              }
            } catch (_) {
              setSheetState(() => isSaveLoading = false);
            }
          }

          // ── Don't suggest (exclude user) ──────────────────────────────────
          Future<void> excludeUser() async {
            if (isActionLoading || currentUserId.isEmpty) return;
            setSheetState(() => isActionLoading = true);
            // Show confirm dialog matching RN's CustomAlertDialog behaviour
            closeSheet();
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dlgCtx) => AlertDialog(
                backgroundColor: c.surface,
                title: Text('Exclude User', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
                content: Text(
                  "Are you sure you want to exclude posts from $userName? You won't see their posts in your recommendations anymore.",
                  style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dlgCtx, rootNavigator: true).pop(false),
                    child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dlgCtx, rootNavigator: true).pop(true),
                    child: const Text("Yes, exclude", style: TextStyle(color: Colors.red, fontFamily: 'Outfit')),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              try {
                await dioClient.post('/v2/excluded-users/add', data: {
                  'user_id': currentUserId,
                  'excluded_user_id': userId,
                });
                // Remove all posts from this user from the feed (triggerRefresh equivalent)
                ref.read(feedNotifierProvider.notifier).removePostsByUser(userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("You won't see posts from $userName anymore."),
                  ));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to exclude user')));
                }
              }
            }
          }

          // ── Unfollow ───────────────────────────────────────────────────────
          Future<void> unfollow() async {
            if (currentUserId.isEmpty) return;
            closeSheet();
            try {
              await dioClient.post('/v1/followers/toggle', data: {'followingId': userId});
              setSheetState(() => isFollowing = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unfollowed user!')));
              }
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update follow status')));
              }
            }
          }

          // ── Not interested ─────────────────────────────────────────────────
          Future<void> notInterested() async {
            closeSheet();
            if (currentUserId.isNotEmpty) {
              postFeedbackService.sendNotInterestedFeedback(userId: currentUserId, postId: postId);
            }
            // Remove post from feed immediately like RN's triggerRefresh
            ref.read(feedNotifierProvider.notifier).removePost(postId);
          }

          // ── Hide post ──────────────────────────────────────────────────────
          Future<void> hidePost() async {
            closeSheet();
            if (currentUserId.isNotEmpty) {
              postFeedbackService.sendHidePostFeedback(userId: currentUserId, postId: postId);
            }
            // Remove post from feed immediately like RN's triggerRefresh
            ref.read(feedNotifierProvider.notifier).removePost(postId);
          }

          return Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),

            if (!isOwnPost) ...[
              // Top button row: Save/Unsave
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: isSaveLoading ? null : toggleSave,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: c.interactionButtonBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isSaveLoading
                            ? Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: c.text, strokeWidth: 2)))
                            : Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: c.text, size: 22),
                                const SizedBox(height: 4),
                                Text(isSaved ? 'Unsave' : 'Save',
                                    style: TextStyle(color: c.text, fontSize: 13, fontFamily: 'Outfit')),
                              ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ],

            if (isOwnPost) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: c.text),
                title: Text('Edit Post', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 16)),
                onTap: () {
                  closeSheet();
                  context.push('/create-post', extra: {
                    'isEditing': true,
                    'postId': postId,
                    'initialContent': extra['content'],
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Color(0xFFFF3040)),
                title: const Text('Delete Post', style: TextStyle(color: Color(0xFFFF3040), fontFamily: 'Outfit', fontSize: 16)),
                onTap: () {
                  closeSheet();
                  _confirmDeletePost(postId, currentUserId, c);
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: c.text),
                title: Text("Don't suggest posts from $userName",
                    style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 16)),
                onTap: excludeUser,
              ),
              if (isFollowing)
                ListTile(
                  leading: Icon(Icons.person_remove_outlined, color: c.text),
                  title: Text('Unfollow', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 16)),
                  onTap: unfollow,
                ),
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: c.text),
                title: Text('Not interested', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 16)),
                onTap: notInterested,
              ),
              ListTile(
                leading: Icon(Icons.visibility_off_outlined, color: c.text),
                title: Text('Hide post', style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 16)),
                onTap: hidePost,
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xFFFF3040)),
                title: const Text('Report', style: TextStyle(color: Color(0xFFFF3040), fontFamily: 'Outfit', fontSize: 16)),
                onTap: () {
                  closeSheet();
                  context.push('/report/post/$postId');
                },
              ),
            ],
            const SizedBox(height: 16),
          ]);
        },
      ),
    );
  }

  Future<void> _confirmDeletePost(String postId, String currentUserId, ThemeColors c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete Post', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
        content: Text('Are you sure you want to delete this post? This action cannot be undone.',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx, rootNavigator: true).pop(false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx, rootNavigator: true).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3040), fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await dioClient.delete('/v1/posts/$postId', data: {'userId': currentUserId});
      ref.read(feedNotifierProvider.notifier).removePost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete post')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feedState = ref.watch(feedNotifierProvider);
    final currentUserId = ref.watch(authProvider).uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        body: _buildBody(feedState, currentUserId, c),
      ),
    );
  }

  Widget _buildBody(FeedState state, String? currentUserId, ThemeColors c) {
    Widget bodySliver;

    if (state.isLoading && state.posts.isEmpty) {
      bodySliver = SliverToBoxAdapter(child: _buildSkeleton(c));
    } else if (state.error != null && state.posts.isEmpty) {
      bodySliver = SliverFillRemaining(child: _buildError(state.error!, c));
    } else if (state.posts.isEmpty) {
      bodySliver = SliverFillRemaining(child: _buildEmpty(c));
    } else {
      bodySliver = SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
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
          childCount: state.posts.length + (state.isFetchingMore ? 1 : 0),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildSliverHeader(c),
        CupertinoSliverRefreshControl(
          onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
        ),
        bodySliver,
      ],
    );
  }

  Widget _buildSliverHeader(ThemeColors c) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final totalH = statusBarH + 52;

    return SliverPersistentHeader(
      floating: true,
      delegate: _BlurHeaderDelegate(
        child: Container(
          decoration: BoxDecoration(
            color: c.background,
            border: Border(bottom: BorderSide(color: c.border, width: 0.7)),
          ),
          padding: EdgeInsets.only(top: statusBarH),
          child: const WiTalkHeader(
            title: 'WiTalk',
            showBorder: false,
            showNotifications: true,
          ),
        ),
        minH: totalH,
        maxH: totalH,
      ),
    );
  }

  Widget _buildSkeleton(ThemeColors c) => Column(
        children: List.generate(
          4,
          (_) => Shimmer.fromColors(
            baseColor: c.surface,
            highlightColor: c.border,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              height: 300,
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
            ),
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

class _BlurHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minH;
  final double maxH;

  const _BlurHeaderDelegate({
    required this.child,
    required this.minH,
    required this.maxH,
  });

  @override
  double get minExtent => minH;

  @override
  double get maxExtent => maxH;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_BlurHeaderDelegate old) =>
      old.minH != minH || old.maxH != maxH || old.child != child;
}
