import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBtnBg = isDark ? const Color(0xFF11151F) : const Color(0xFFF5F5F5);
    // Capture before async gap so navigation works after sheet closes
    final nav = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);

    // RN: always reset to false + checkingSaveStatus=true on every open, fetch from server
    bool isSaved = false;
    bool isSaveChecking = true;
    bool isSaveLoading = false;
    bool isFollowing = extra['isFollowing'] == true;
    final userName = (extra['userName'] as String?) ?? 'this user';
    final suffix = extra['suffix'] as String?;

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) {
          void closeSheet() => Navigator.of(sheetCtx, rootNavigator: true).pop();

          Future<void> checkSaveStatus() async {
            if (currentUserId.isEmpty) {
              setSheetState(() => isSaveChecking = false);
              return;
            }
            try {
              final res = await dioClient.get('/v1/post-saves/check/$currentUserId/$postId');
              final saved = res.data['data']?['isSaved'] == true;
              setSheetState(() { isSaved = saved; isSaveChecking = false; });
            } catch (_) {
              setSheetState(() { isSaved = false; isSaveChecking = false; });
            }
          }

          Future<void> toggleSave() async {
            if (isSaveLoading || isSaveChecking || currentUserId.isEmpty) return;
            setSheetState(() => isSaveLoading = true);
            try {
              final res = await dioClient.post('/v1/post-saves/toggle',
                  data: {'postId': postId, 'userId': currentUserId});
              final action = res.data['action'] as String?;
              final saved = action == 'saved';
              setSheetState(() { isSaved = saved; isSaveLoading = false; });
              if (saved && currentUserId.isNotEmpty) {
                postFeedbackService.sendSaveFeedback(userId: currentUserId, postId: postId);
              }
            } catch (_) {
              setSheetState(() => isSaveLoading = false);
            }
          }

          void openQrCode() {
            closeSheet();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              final shareUrl = suffix != null && suffix.isNotEmpty
                  ? 'https://witalk.in/p/$suffix'
                  : 'https://witalk.in/post/$postId';
              showModalBottomSheet(
                useRootNavigator: true,
                isScrollControlled: true,
                context: context,
                backgroundColor: c.bottomSheetBg,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (qrCtx) {
                  final screenW = MediaQuery.of(qrCtx).size.width;
                  final qrSize = screenW - 80;
                  return SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 36, height: 5,
                          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(height: 20),
                        Text('QR Code', style: TextStyle(color: c.text, fontSize: 18,
                            fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Scan this QR code to view the post',
                            style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit')),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Center(
                            child: QrImageView(data: shareUrl, version: QrVersions.auto,
                                size: qrSize, backgroundColor: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  );
                },
              );
            });
          }

          Future<void> excludeUser() async {
            closeSheet();
            if (currentUserId.isEmpty) return;
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
                    child: const Text('Yes, exclude', style: TextStyle(color: Colors.red, fontFamily: 'Outfit')),
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
                ref.read(feedNotifierProvider.notifier).removePostsByUser(userId);
              } catch (_) {}
            }
          }

          Future<void> unfollow() async {
            if (currentUserId.isEmpty) return;
            closeSheet();
            try {
              await dioClient.post('/v1/followers/toggle', data: {'followingId': userId});
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unfollowed user!')));
            } catch (_) {}
          }

          Widget topBtn(IconData icon, String label, VoidCallback? onTap, {bool loading = false}) {
            return Expanded(child: GestureDetector(
              onTap: loading ? null : onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(color: topBtnBg, borderRadius: BorderRadius.circular(8)),
                child: loading
                    ? Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: c.text, strokeWidth: 2)))
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, color: c.text, size: 20),
                        const SizedBox(height: 4),
                        Text(label, style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit')),
                      ]),
              ),
            ));
          }

          Widget menuItem(IconData icon, String label, VoidCallback onTap, {bool destructive = false}) {
            final color = destructive ? const Color(0xFFFF3040) : c.text;
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(label, style: TextStyle(color: color, fontFamily: 'Outfit', fontSize: 16)),
              onTap: onTap,
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) => checkSaveStatus());

          return Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 5,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                topBtn(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  isSaved ? 'Unsave' : 'Save',
                  toggleSave,
                  loading: isSaveChecking || isSaveLoading,
                ),
                const SizedBox(width: 12),
                topBtn(Icons.qr_code, 'QR code', openQrCode),
              ]),
            ),
            const SizedBox(height: 24),

            if (isOwnPost) ...[
              menuItem(Icons.edit_outlined, 'Edit Post', () {
                nav.pop();
                router.push('/create-post', extra: {
                  'isEditing': true,
                  'postId': postId,
                  'initialContent': extra['content'],
                });
              }),
              menuItem(Icons.delete_outlined, 'Delete Post', () {
                nav.pop();
                _confirmDeletePost(postId, currentUserId, c);
              }, destructive: true),
            ] else ...[
              menuItem(Icons.cancel_outlined, "Don't suggest posts from $userName", excludeUser),
              if (isFollowing)
                menuItem(Icons.person_remove_outlined, 'Unfollow', unfollow),
              menuItem(Icons.person_outlined, 'About this account', () {
                nav.pop();
                router.push('/about-account/$userId');
              }),
              menuItem(Icons.flag_outlined, 'Report', () {
                nav.pop();
                router.push('/report/post/$postId');
              }, destructive: true),
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
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      bodySliver = SliverToBoxAdapter(child: _buildSkeleton(c, isDark));
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

  Widget _buildSkeleton(ThemeColors c, bool isDark) {
    final baseColor = isDark ? const Color(0xFF1A1F2E) : const Color(0xFFE1E9EE);
    final highlightColor = isDark ? const Color(0xFF242938) : const Color(0xFFF2F8FC);
    final screenW = MediaQuery.of(context).size.width;

    // The card background must be OUTSIDE Shimmer so only the white boxes animate.
    Widget skBox({double? w, double? h, double r = 6, bool circle = false}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: circle ? null : BorderRadius.circular(r),
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
          ),
        );

    Widget postSkeleton() => Container(
          color: c.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  skBox(w: 40, h: 40, circle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      skBox(w: screenW * 0.38, h: 14),
                      const SizedBox(height: 6),
                      skBox(w: screenW * 0.24, h: 12),
                    ]),
                  ),
                  skBox(w: 60, h: 28, r: 8),
                  const SizedBox(width: 8),
                  skBox(w: 20, h: 20, r: 4),
                ]),
              ),
            ),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  skBox(w: screenW - 32, h: 12),
                  const SizedBox(height: 6),
                  skBox(w: (screenW - 32) * 0.88, h: 12),
                  const SizedBox(height: 6),
                  skBox(w: (screenW - 32) * 0.58, h: 12),
                ]),
              ),
            ),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: skBox(w: screenW, h: screenW, r: 0),
            ),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                child: Row(children: [
                  skBox(w: 70, h: 35, r: 100),
                  const SizedBox(width: 10),
                  skBox(w: 70, h: 35, r: 100),
                  const SizedBox(width: 10),
                  skBox(w: 70, h: 35, r: 100),
                ]),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: c.border),
          ]),
        );

    return Column(children: List.generate(3, (_) => postSkeleton()));
  }

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
