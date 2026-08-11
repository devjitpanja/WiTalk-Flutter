import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import '../../api/dio_client.dart';
import '../../services/post_view_tracking_service.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/common/comment_bottom_sheet.dart';
import '../../widgets/common/share_bottom_sheet.dart';
import '../../widgets/common/verification_badge.dart';
import '../../cache/witalk_image_cache.dart';

String _formatCount(int n) {
  if (n >= 1000000) {
    final s = (n / 1000000).toStringAsFixed(1);
    return s.endsWith('.0') ? '${n ~/ 1000000}M' : '${s}M';
  }
  if (n >= 1000) {
    final s = (n / 1000).toStringAsFixed(1);
    return s.endsWith('.0') ? '${n ~/ 1000}k' : '${s}k';
  }
  return '$n';
}

// Global mute state shared across all video items (matches RN globalMuteState)
bool _globalMuted = false;

// ─── MiniScreen ──────────────────────────────────────────────────────────────

class MiniScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> initialPosts;
  final int initialIndex;
  final String? currentUserId;
  final bool fromVideoClick;

  const MiniScreen({
    super.key,
    this.initialPosts = const [],
    this.initialIndex = 0,
    this.currentUserId,
    this.fromVideoClick = false,
  });

  @override
  ConsumerState<MiniScreen> createState() => _MiniScreenState();
}

class _MiniScreenState extends ConsumerState<MiniScreen> with TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();

  final _pageCtrl = PageController();

  List<Map<String, dynamic>> _posts = [];
  int _currentIndex = 0;

  bool _loadingInitial = true;
  bool _loadingMore    = false;
  bool _hasMore        = true;
  int  _page           = 1;

  String? _userId;

  // Header hide/show animation — mirrors RN's headerOpacity Animated.Value
  late AnimationController _headerOpacityCtrl;
  double _lastScrollOffset = 0;

  // Track which userId is currently being followed (for loading spinner)
  String? _followingUserId;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentIndex = widget.initialIndex;
    _headerOpacityCtrl = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 200),
    );
    _init();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    _headerOpacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = widget.currentUserId ?? await _storage.read(key: 'uid');
    if (mounted) setState(() => _userId = uid);

    if (widget.initialPosts.isNotEmpty) {
      final filtered = _filterVideoPosts(widget.initialPosts);
      if (mounted) setState(() { _posts = filtered; _loadingInitial = false; });
      _fetchMore(reset: false);
    } else {
      await _fetchMore(reset: true);
    }
  }

  List<Map<String, dynamic>> _filterVideoPosts(List<Map<String, dynamic>> raw) {
    return raw.where((p) {
      final media    = p['media'] as List?;
      final hasVideo = media?.any((m) => (m as Map)['type'] == 'video') == true;
      return hasVideo || p['media_type'] == 'video';
    }).toList();
  }

  Future<void> _fetchMore({bool reset = false}) async {
    if (_loadingMore || (!_hasMore && !reset)) return;
    setState(() => _loadingMore = true);

    final page = reset ? 1 : _page + 1;
    try {
      final uid = _userId ?? await _storage.read(key: 'uid');
      final res = await dioClient.get('/v1/posts/recommended', queryParameters: {
        if (uid != null) 'userId': uid,
        'page': page,
        'limit': 10,
        'type': 'video',
      });
      final rawPosts = (res.data['data']?['posts'] ?? res.data['posts'] ?? []) as List;
      final newPosts = _filterVideoPosts(
          rawPosts.whereType<Map<String, dynamic>>().toList());

      if (mounted) {
        setState(() {
          if (reset) {
            _posts = newPosts;
            _loadingInitial = false;
          } else {
            final existing = Set<dynamic>.from(_posts.map((p) => p['id']));
            _posts.addAll(newPosts.where((p) => !existing.contains(p['id'])));
          }
          _page    = page;
          _hasMore = newPosts.length >= 10;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInitial = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (_posts.length - index <= 3 && !_loadingMore && _hasMore) {
      _fetchMore();
    }
  }

  // Mirror RN scroll handler — hide on swipe-down, show on swipe-up
  void _onPageScrolled(double offset) {
    final diff = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (diff > 2 && _headerOpacityCtrl.value > 0) {
      _headerOpacityCtrl.animateTo(0.0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else if (diff < -2 && _headerOpacityCtrl.value < 1) {
      _headerOpacityCtrl.animateTo(1.0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
    }
  }

  Future<void> _toggleLike(int index) async {
    if (_userId == null) return;
    final post      = _posts[index];
    final prev      = post['isLiked'] == true;
    final prevCount = (post['likes'] ?? 0) as int;
    setState(() {
      _posts[index] = {
        ...post,
        'isLiked': !prev,
        'likes': !prev ? prevCount + 1 : (prevCount - 1).clamp(0, prevCount),
      };
    });
    try {
      final res = await dioClient.post('/v1/like/post/toggle',
          data: {'postId': post['id'].toString(), 'userId': _userId});
      final action = res.data['action'];
      final finalLiked = (action == 'liked' || action == true) ? true
          : (action == 'unliked' || action == false) ? false
          : !prev;
      final finalCount = finalLiked ? prevCount + 1 : (prevCount - 1).clamp(0, prevCount);
      if (mounted) {
        setState(() {
          _posts[index] = {..._posts[index], 'isLiked': finalLiked, 'likes': finalCount};
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts[index] = {..._posts[index], 'isLiked': prev, 'likes': prevCount};
        });
      }
    }
  }

  Future<void> _toggleFollow(int index) async {
    if (_userId == null) return;
    final post     = _posts[index];
    final uid      = ((post['user'] as Map?)?['id'] ?? post['user_id'])?.toString();
    if (uid == null || uid == _userId || _followingUserId != null) return;

    final wasFollowing = post['isFollowing'] == true;
    setState(() {
      _followingUserId = uid;
      _posts[index] = {...post, 'isFollowing': !wasFollowing};
    });
    try {
      await dioClient.post('/v1/followers/toggle', data: {'followingId': uid});
      // Sync all posts by the same user
      if (mounted) {
        setState(() {
          for (var i = 0; i < _posts.length; i++) {
            final pUid = ((_posts[i]['user'] as Map?)?['id'] ??
                _posts[i]['user_id'])?.toString();
            if (pUid == uid) {
              _posts[i] = {..._posts[i], 'isFollowing': !wasFollowing};
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _posts[index] = {..._posts[index], 'isFollowing': wasFollowing});
    } finally {
      if (mounted) setState(() => _followingUserId = null);
    }
  }

  void _openComments(int index) {
    final post = _posts[index];
    showCommentBottomSheet(
      context,
      post: post,
      currentUserId: _userId,
      onCommentAdded: () {
        final count = (post['comments'] ?? 0) as int;
        if (mounted) {
          setState(() {
            _posts[index] = {...post, 'comments': count + 1};
          });
        }
      },
    );
  }

  void _showMoreMenu(int index) {
    final post        = _posts[index];
    final user        = post['user'] as Map<String, dynamic>?;
    final postId      = post['id']?.toString() ?? '';
    final postUserId  = (user?['id'] ?? post['user_id'])?.toString() ?? '';
    final userName    = (user?['name'] ?? 'this user') as String;
    final suffix      = post['suffix']?.toString();
    final isOwnPost   = _userId != null && _userId == postUserId;
    final c           = context.colors;

    if (postId.isEmpty || postUserId.isEmpty) return;

    bool isSaved        = false;
    bool isSaveChecking = true;
    bool isSaveLoading  = false;

    final nav    = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) {
          void closeSheet() => Navigator.of(sheetCtx, rootNavigator: true).pop();

          Future<void> checkSaveStatus() async {
            if (_userId == null) {
              setSheetState(() => isSaveChecking = false);
              return;
            }
            try {
              final res = await dioClient.get('/v1/post-saves/check/$_userId/$postId');
              setSheetState(() {
                isSaved        = res.data['data']?['isSaved'] == true;
                isSaveChecking = false;
              });
            } catch (_) {
              setSheetState(() { isSaved = false; isSaveChecking = false; });
            }
          }

          Future<void> toggleSave() async {
            if (isSaveLoading || isSaveChecking || _userId == null) return;
            setSheetState(() => isSaveLoading = true);
            try {
              final res = await dioClient.post('/v1/post-saves/toggle',
                  data: {'postId': postId, 'userId': _userId});
              final saved = res.data['action'] == 'saved';
              setSheetState(() { isSaved = saved; isSaveLoading = false; });
            } catch (_) {
              setSheetState(() => isSaveLoading = false);
            }
          }

          Future<void> doExcludeUser() async {
            closeSheet();
            if (_userId == null) return;
            try {
              await dioClient.post('/v2/excluded-users/add', data: {
                'user_id': _userId,
                'excluded_user_id': postUserId,
              });
            } catch (_) {}
          }

          Future<void> doUnfollow() async {
            closeSheet();
            try {
              await dioClient.post('/v1/followers/toggle', data: {'followingId': postUserId});
              if (mounted) {
                setState(() {
                  for (var i = 0; i < _posts.length; i++) {
                    final uid = ((_posts[i]['user'] as Map?)?['id'] ??
                        _posts[i]['user_id'])?.toString();
                    if (uid == postUserId) {
                      _posts[i] = {..._posts[i], 'isFollowing': false};
                    }
                  }
                });
              }
            } catch (_) {}
          }

          void openQrCode() {
            closeSheet();
            final shareUrl = (suffix != null && suffix.isNotEmpty)
                ? 'https://witalk.in/p/$suffix'
                : 'https://witalk.in/post/$postId';
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              _showQrCodeModal(shareUrl);
            });
          }

          WidgetsBinding.instance.addPostFrameCallback((_) => checkSaveStatus());

          final isDark    = Theme.of(sheetCtx).brightness == Brightness.dark;
          final topBtnBg  = isDark ? const Color(0xFF11151F) : const Color(0xFFF5F5F5);
          final isFollowing = (_posts.firstWhere(
              (p) => p['id']?.toString() == postId,
              orElse: () => post)['isFollowing'] == true);

          return Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 5,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _topSheetButton(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  label: isSaved ? 'Unsave' : 'Save',
                  loading: isSaveChecking || isSaveLoading,
                  onTap: toggleSave,
                  c: c,
                  bgColor: topBtnBg,
                )),
                const SizedBox(width: 12),
                Expanded(child: _topSheetButton(
                  icon: Icons.qr_code,
                  label: 'QR code',
                  loading: false,
                  onTap: openQrCode,
                  c: c,
                  bgColor: topBtnBg,
                )),
              ]),
            ),
            const SizedBox(height: 24),

            if (isOwnPost) ...[
              _menuItem(Icons.edit_outlined, 'Edit Post', c, onTap: () {
                closeSheet();
                router.push('/create-post', extra: {
                  'isEditing': true,
                  'postId': postId,
                  'initialContent': post['content'],
                });
              }),
              _menuItem(Icons.delete_outlined, 'Delete Post', c, isDestructive: true, onTap: () {
                closeSheet();
                _confirmDelete(postId, index);
              }),
            ] else ...[
              _menuItem(Icons.cancel_outlined, "Don't suggest posts from $userName", c, onTap: () => doExcludeUser()),
              if (isFollowing)
                _menuItem(Icons.person_remove_outlined, 'Unfollow', c, onTap: () => doUnfollow()),
              _menuItem(Icons.person_outlined, 'About this account', c, onTap: () {
                nav.pop();
                router.push('/about-account/$postUserId');
              }),
              _menuItem(Icons.flag_outlined, 'Report', c, isDestructive: true, onTap: () {
                nav.pop();
                router.push('/report/post/$postId');
              }),
            ],
            const SizedBox(height: 16),
          ]);
        },
      ),
    );
  }

  void _showQrCodeModal(String shareUrl) {
    final c = context.colors;
    showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final screenW = MediaQuery.of(ctx).size.width;
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: QrImageView(
                    data: shareUrl,
                    version: QrVersions.auto,
                    size: screenW - 80,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String postId, int index) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Delete post', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
        content: Text('Are you sure you want to delete this post?',
            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx, rootNavigator: true).pop(false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dlgCtx, rootNavigator: true).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await dioClient.delete('/v1/posts/$postId', data: {'userId': _userId ?? ''});
      if (mounted) {
        setState(() => _posts.removeAt(index));
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

  Widget _topSheetButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeColors c,
    required Color bgColor,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: loading
            ? Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: c.text, strokeWidth: 2)))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: c.text, size: 20),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit')),
              ]),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, ThemeColors c, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFFF3040) : c.text;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontFamily: 'Outfit', fontSize: 16)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          _MiniSkeleton(),
          SafeArea(
            bottom: false,
            child: _buildHeader(),
          ),
        ]),
      );
    }

    if (_posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: Column(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_off, size: 64, color: Colors.white38),
              SizedBox(height: 16),
              Text('No videos available',
                  style: TextStyle(color: Colors.white54, fontFamily: 'Outfit', fontSize: 16)),
            ]),
          )),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollUpdateNotification) {
                    _onPageScrolled(n.metrics.pixels);
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageCtrl,
                  scrollDirection: Axis.vertical,
                  itemCount: _posts.length + (_loadingMore ? 1 : 0),
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) {
                    if (i >= _posts.length) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.white));
                    }
                    return _MiniItem(
                      post: _posts[i],
                      isActive: i == _currentIndex,
                      currentUserId: _userId,
                      followingUserId: _followingUserId,
                      onLike: () => _toggleLike(i),
                      onComment: () => _openComments(i),
                      onFollow: () => _toggleFollow(i),
                      onMore: () => _showMoreMenu(i),
                    );
                  },
                ),
              ),
            ),

            // Animated header overlay
            SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _headerOpacityCtrl,
                child: _buildHeader(),
              ),
            ),
          ]),
        ),

        if (widget.fromVideoClick)
          _CommentFooter(
            onTap: _posts.isNotEmpty ? () => _openComments(_currentIndex) : null,
          ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => context.pop(),
        ),
        const Expanded(
          child: Text('Mini', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 48),
      ]),
    );
  }
}

// ─── Skeleton loading screen ──────────────────────────────────────────────────

class _MiniSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1a1f2e),
      highlightColor: const Color(0xFF242938),
      child: Container(
        color: const Color(0xFF1a1f2e),
        child: Stack(children: [
          // User info bottom-left
          Positioned(
            left: 16,
            bottom: 40,
            right: 80,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 35, height: 35,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Container(width: 120, height: 16,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ]),
              const SizedBox(height: 10),
              Container(width: double.infinity, height: 14,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Container(width: 180, height: 14,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
            ]),
          ),
          // Action buttons right-side
          Positioned(
            right: 12,
            bottom: 60,
            child: Column(children: [
              _skeletonCircle(48),
              const SizedBox(height: 20),
              _skeletonCircle(48),
              const SizedBox(height: 20),
              _skeletonCircle(48),
              const SizedBox(height: 20),
              _skeletonCircle(48),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _skeletonCircle(double size) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}

// ─── Single reel item ─────────────────────────────────────────────────────────

class _MiniItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final String? currentUserId;
  final String? followingUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFollow;
  final VoidCallback onMore;

  const _MiniItem({
    required this.post,
    required this.isActive,
    this.currentUserId,
    this.followingUserId,
    required this.onLike,
    required this.onComment,
    required this.onFollow,
    required this.onMore,
  });

  @override
  State<_MiniItem> createState() => _MiniItemState();
}

class _MiniItemState extends State<_MiniItem> with TickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _initialized  = false;
  bool _isBuffering  = false;
  bool _hasError     = false;
  bool _holdPaused   = false;

  bool _muted = _globalMuted;

  bool _showMuteIndicator = false;
  Timer? _muteIndicatorTimer;

  int? _lastTapMs;
  Timer? _singleTapTimer;
  static const _doubleTapMs = 300;

  late AnimationController _uiOpacityCtrl;
  bool _isHolding = false;
  Timer? _holdTimer;

  late AnimationController _heartCtrl;
  bool _showHeart = false;

  // Like button scale animation
  late AnimationController _likeScaleCtrl;

  // Caption expand/collapse
  bool _captionExpanded = false;
  late AnimationController _captionCtrl;

  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  // View tracking
  final _tracker = postViewTrackingService;

  @override
  void initState() {
    super.initState();
    _uiOpacityCtrl = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 200),
    );
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _heartCtrl.reverse();
        });
      }
      if (s == AnimationStatus.dismissed && mounted) {
        setState(() => _showHeart = false);
      }
    });
    _likeScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 1.0,
      upperBound: 1.3,
    );
    _captionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initVideo();
    _startTrackingIfActive();
  }

  @override
  void didUpdateWidget(_MiniItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive && !_holdPaused) {
        _ctrl?.play();
        _startTracking();
      } else if (!widget.isActive) {
        _ctrl?.pause();
        _holdPaused = false;
        _stopTracking(wasSkipped: true);
      }
    }
  }

  @override
  void dispose() {
    _muteIndicatorTimer?.cancel();
    _singleTapTimer?.cancel();
    _holdTimer?.cancel();
    _uiOpacityCtrl.dispose();
    _heartCtrl.dispose();
    _likeScaleCtrl.dispose();
    _captionCtrl.dispose();
    _ctrl?.removeListener(_onVideoListener);
    _ctrl?.dispose();
    if (widget.isActive) {
      _stopTracking(wasSkipped: true);
    }
    super.dispose();
  }

  // ── View tracking ─────────────────────────────────────────────────────────

  void _startTrackingIfActive() {
    if (widget.isActive) _startTracking();
  }

  void _startTracking() {
    final uid = widget.currentUserId;
    final pid = widget.post['id']?.toString();
    if (uid == null || pid == null) return;
    _tracker.startTracking(
      postId: pid,
      userId: uid,
      screenType: 'mini',
      interactionType: 'swipe',
    );
  }

  void _stopTracking({bool wasSkipped = false, bool isCompleted = false}) {
    final uid = widget.currentUserId;
    final pid = widget.post['id']?.toString();
    if (uid == null || pid == null) return;
    _tracker.stopAndSend(pid, uid,
        wasSkipped: wasSkipped, isCompleted: isCompleted);
  }

  // ── Video ─────────────────────────────────────────────────────────────────

  String? get _videoUrl {
    final media = widget.post['media'] as List?;
    final vid   = media?.firstWhere(
      (m) => (m as Map)['type'] == 'video',
      orElse: () => null,
    );
    return (vid as Map?)?['url'] as String? ?? widget.post['videoUrl'] as String?;
  }

  String? get _thumbnail {
    final media = widget.post['media'] as List?;
    final vid   = media?.firstWhere(
      (m) => (m as Map)['type'] == 'video',
      orElse: () => null,
    );
    return (vid as Map?)?['thumbnail'] as String? ?? widget.post['thumbnail'] as String?;
  }

  bool _coverMode = true;

  void _initVideo() {
    final url = _videoUrl;
    if (url == null || url.isEmpty) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..setVolume(_muted ? 0.0 : 1.0);
    _ctrl = ctrl;
    ctrl.addListener(_onVideoListener);
    ctrl.initialize().then((_) {
      if (mounted) {
        final size = ctrl.value.size;
        final ar   = size.height > 0 ? size.width / size.height : 0.0;
        setState(() {
          _initialized   = true;
          _hasError      = false;
          _videoDuration = ctrl.value.duration;
          _coverMode     = ar >= 0.4 && ar <= 0.8;
        });
        if (widget.isActive && !_holdPaused) ctrl.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => _hasError = true);
    });
  }

  void _retryVideo() {
    _ctrl?.removeListener(_onVideoListener);
    _ctrl?.dispose();
    _ctrl = null;
    setState(() {
      _initialized  = false;
      _hasError     = false;
      _isBuffering  = true;
    });
    _initVideo();
  }

  void _onVideoListener() {
    if (!mounted || _ctrl == null) return;
    final v = _ctrl!.value;
    // Track completion when looping crosses end
    if (v.position >= v.duration && v.duration > Duration.zero && !v.isPlaying) {
      _stopTracking(isCompleted: true);
      _startTracking();
    }
    final buffering = v.isBuffering;
    final position  = v.position;
    if (buffering != _isBuffering || position != _videoPosition) {
      setState(() {
        _isBuffering   = buffering;
        _videoPosition = position;
        _videoDuration = v.duration;
      });
    }
  }

  // ── Tap handling ──────────────────────────────────────────────────────────

  double _itemHeight = 0;

  void _handleTap(TapUpDetails details) {
    if (_itemHeight > 0 && details.localPosition.dy > _itemHeight - 200) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _singleTapTimer?.cancel();
    _singleTapTimer = null;

    if (_lastTapMs != null && now - _lastTapMs! < _doubleTapMs) {
      _lastTapMs = null;
      _handleDoubleTap();
      return;
    }

    _lastTapMs = now;
    _singleTapTimer = Timer(const Duration(milliseconds: _doubleTapMs), () {
      if (!mounted) return;
      setState(() {
        _muted       = !_muted;
        _globalMuted = _muted;
        _ctrl?.setVolume(_muted ? 0.0 : 1.0);
        _showMuteIndicator = true;
      });
      _muteIndicatorTimer?.cancel();
      _muteIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showMuteIndicator = false);
      });
    });
  }

  void _handleDoubleTap() {
    if (!_isLiked) widget.onLike();
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0);
  }

  // ── Long press (hold-to-pause) ────────────────────────────────────────────

  void _handlePressDown(TapDownDetails _) {
    _holdTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (_ctrl?.value.isPlaying == true) {
        _ctrl?.pause();
        setState(() { _isHolding = true; _holdPaused = true; });
        _tracker.incrementPause(
            widget.post['id']?.toString() ?? '', widget.currentUserId ?? '');
        _uiOpacityCtrl.animateTo(0.0,
            duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
      }
    });
  }

  void _handlePressUp(TapUpDetails details) {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_isHolding) {
      setState(() => _isHolding = false);
      _uiOpacityCtrl.animateTo(1.0,
          duration: const Duration(milliseconds: 150), curve: Curves.easeIn);
      if (widget.isActive) {
        _ctrl?.play();
        setState(() => _holdPaused = false);
      }
    } else {
      _handleTap(details);
    }
  }

  void _handlePressCancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_isHolding) {
      setState(() => _isHolding = false);
      _uiOpacityCtrl.animateTo(1.0,
          duration: const Duration(milliseconds: 150), curve: Curves.easeIn);
      if (widget.isActive) {
        _ctrl?.play();
        setState(() => _holdPaused = false);
      }
    }
  }

  void _seekTo(Duration position) {
    _ctrl?.seekTo(position);
    setState(() => _videoPosition = position);
  }

  bool get _isLiked     => widget.post['isLiked'] == true;
  bool get _isFollowing => widget.post['isFollowing'] == true;
  Map<String, dynamic>? get _user => widget.post['user'] as Map<String, dynamic>?;

  @override
  Widget build(BuildContext context) {
    final name       = (_user?['name'] ?? '') as String;
    final username   = (_user?['username'] as String?)?.isNotEmpty == true
        ? '@${_user!['username']}'
        : name;
    final pic        = _user?['profile_pic'] as String?;
    final isVerified = _user?['is_verified'] == true;
    final badgeData  = _user?['verification_badge'] as Map<String, dynamic>?;
    final content    = (widget.post['content'] ?? '') as String;
    final likes      = (widget.post['likes'] ?? 0) as int;
    final comments   = (widget.post['comments'] ?? 0) as int;
    final shares     = (widget.post['shares'] ?? 0) as int;
    final userId     = ((_user?['id'] ?? widget.post['user_id']) ?? '').toString();
    final isOwnPost  = widget.currentUserId != null && widget.currentUserId == userId;
    final isLoadingFollow = widget.followingUserId == userId;

    return LayoutBuilder(
      builder: (context, constraints) {
        _itemHeight = constraints.maxHeight;
        return GestureDetector(
          onTapDown:   _handlePressDown,
          onTapUp:     _handlePressUp,
          onTapCancel: _handlePressCancel,
          child: Stack(fit: StackFit.expand, children: [

            Container(color: Colors.black),

            // Thumbnail
            if (_thumbnail != null && !_initialized)
              Positioned.fill(
                child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),
                  imageUrl: _thumbnail!,
                  fit: _coverMode ? BoxFit.cover : BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

            // Video
            if (_initialized && _ctrl != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: _coverMode ? BoxFit.cover : BoxFit.contain,
                  child: SizedBox(
                    width:  _ctrl!.value.size.width,
                    height: _ctrl!.value.size.height,
                    child:  VideoPlayer(_ctrl!),
                  ),
                ),
              ),

            // Buffering spinner
            if (!_initialized && !_hasError || _isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
              ),

            // Error state
            if (_hasError)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 60),
                  const SizedBox(height: 12),
                  const Text('Failed to load video',
                      style: TextStyle(color: Colors.white70, fontFamily: 'Outfit', fontSize: 15)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _retryVideo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Retry',
                          style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),

            // Gradient overlay
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80000000), Colors.transparent, Color(0xCC000000)],
                  stops: [0, 0.4, 1],
                ),
              ),
            ))),

            // UI layer (fades during hold)
            FadeTransition(
              opacity: _uiOpacityCtrl,
              child: Stack(children: [

                // Bottom-left: user info + caption
                Positioned(left: 16, right: 80, bottom: 16,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: () => context.push('/user/$userId'),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 17.5,
                          backgroundColor: Colors.white24,
                          backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                          child: pic == null
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 12))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(username,
                          style: const TextStyle(color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w700, fontFamily: 'Outfit',
                              shadows: [Shadow(blurRadius: 8)]),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          VerificationBadge(isVerified: true, badge: badgeData, size: 14),
                        ],
                        if (!isOwnPost && !_isFollowing) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: isLoadingFollow ? null : widget.onFollow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white70),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: isLoadingFollow
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Follow',
                                      style: TextStyle(color: Colors.white, fontSize: 12,
                                          fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ]),
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() => _captionExpanded = !_captionExpanded);
                          if (_captionExpanded) {
                            _captionCtrl.forward();
                          } else {
                            _captionCtrl.reverse();
                          }
                        },
                        child: Text(content,
                          style: const TextStyle(color: Colors.white, fontSize: 14,
                              fontFamily: 'Outfit', height: 1.4,
                              shadows: [Shadow(blurRadius: 8)]),
                          maxLines: _captionExpanded ? null : 2,
                          overflow: _captionExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                ),

                // Right-side action buttons
                Positioned(right: 12, bottom: 16,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Like
                    _AnimatedActionBtn(
                      label: _formatCount(likes),
                      onTap: widget.onLike,
                      child: Icon(
                        _isLiked
                            ? const IconData(0xe2a8, fontFamily: 'PhosphorFill', fontPackage: 'phosphor_flutter')
                            : const IconData(0xe2a8, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
                        size: 35,
                        color: _isLiked ? const Color(0xFFFF3040) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Comment
                    _ActionBtn(
                      label: _formatCount(comments),
                      onTap: widget.onComment,
                      child: const Icon(
                        IconData(0xe168, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Share
                    _ActionBtn(
                      label: _formatCount(shares),
                      onTap: () => showShareBottomSheet(
                        context,
                        shareType: ShareType.post,
                        postData: SharePostData(
                          id: widget.post['id']?.toString(),
                          suffix: widget.post['suffix']?.toString(),
                          content: widget.post['content']?.toString(),
                          userId: (widget.post['user_id'] ?? _user?['id'])?.toString(),
                          user: _user,
                          media: widget.post['media'],
                          mediaType: 'video',
                          isMini: true,
                        ),
                      ),
                      child: const Icon(
                        IconData(0xe398, fontFamily: 'PhosphorBold', fontPackage: 'phosphor_flutter'),
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // More (dots)
                    _ActionBtn(
                      label: '',
                      onTap: widget.onMore,
                      child: const Icon(
                        Icons.more_horiz,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

            // Seekbar
            if (widget.isActive)
              Positioned(left: 0, right: 0, bottom: 0,
                child: _MiniSeekBar(
                  position: _videoPosition,
                  duration: _videoDuration,
                  thumbnail: _thumbnail,
                  onSeek: _seekTo,
                ),
              ),

            // Mute indicator
            if (_showMuteIndicator)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white, size: 28,
                    ),
                  ),
                ),
              ),

            // Double-tap heart
            if (_showHeart)
              IgnorePointer(
                child: Center(
                  child: FadeTransition(
                    opacity: _heartCtrl,
                    child: ScaleTransition(
                      scale: _heartCtrl.drive(
                        Tween(begin: 0.5, end: 1.2)
                            .chain(CurveTween(curve: Curves.elasticOut)),
                      ),
                      child: const Icon(Icons.favorite, color: Color(0xFFFF3040), size: 100),
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ─── Custom seek bar ─────────────────────────────────────────────────────────

class _MiniSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final String? thumbnail;
  final ValueChanged<Duration> onSeek;

  const _MiniSeekBar({
    required this.position,
    required this.duration,
    this.thumbnail,
    required this.onSeek,
  });

  @override
  State<_MiniSeekBar> createState() => _MiniSeekBarState();
}

class _MiniSeekBarState extends State<_MiniSeekBar>
    with SingleTickerProviderStateMixin {
  bool   _isDragging   = false;
  double _dragProgress = 0.0;
  double _previewProgress = 0.0;
  double _barWidth     = 0.0;

  late AnimationController _opacityCtrl;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _opacityCtrl = AnimationController(
      vsync: this,
      value: 0.5,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _opacityCtrl.dispose();
    super.dispose();
  }

  void _showFull() {
    _fadeTimer?.cancel();
    _opacityCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    _fadeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _opacityCtrl.animateTo(0.5,
            duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
      }
    });
  }

  double get _currentProgress {
    if (_isDragging) return _dragProgress;
    final dur = widget.duration.inMilliseconds;
    if (dur <= 0) return 0;
    return (widget.position.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.duration == Duration.zero) return;
    _showFull();
    final p = (details.localPosition.dx / _barWidth).clamp(0.0, 1.0);
    setState(() { _isDragging = true; _dragProgress = p; _previewProgress = p; });
    widget.onSeek(Duration(milliseconds: (p * widget.duration.inMilliseconds).round()));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || widget.duration == Duration.zero) return;
    final p = (details.localPosition.dx / _barWidth).clamp(0.0, 1.0);
    setState(() { _dragProgress = p; _previewProgress = p; });
    widget.onSeek(Duration(milliseconds: (p * widget.duration.inMilliseconds).round()));
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_isDragging) return;
    widget.onSeek(Duration(
      milliseconds: (_dragProgress * widget.duration.inMilliseconds).round()));
    setState(() => _isDragging = false);
    _showFull();
  }

  @override
  Widget build(BuildContext context) {
    final screenW  = MediaQuery.of(context).size.width;
    final previewX = (_previewProgress * screenW).clamp(60.0, screenW - 60.0);
    final previewDuration = Duration(
      milliseconds: (_previewProgress * widget.duration.inMilliseconds).round(),
    );

    return SizedBox(
      height: 200,
      child: Stack(clipBehavior: Clip.none, children: [

        if (_isDragging && widget.duration != Duration.zero)
          Positioned(
            bottom: 54,
            left: previewX - 60,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 120, height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xF21C1C1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.thumbnail != null
                    ? CachedNetworkImage(
        cacheManager: WiTalkImageCache(),imageUrl: widget.thumbnail!, fit: BoxFit.cover)
                    : const ColoredBox(color: Colors.black),
              ),
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(_formatTime(previewDuration),
                    style: const TextStyle(color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
              ),
              CustomPaint(size: const Size(16, 8), painter: _ArrowPainter()),
            ]),
          ),

        Positioned(
          left: 0, right: 0, bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onPanStart,
            onHorizontalDragUpdate: _onPanUpdate,
            onHorizontalDragEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: _opacityCtrl,
              builder: (_, snap) => Opacity(
                opacity: _opacityCtrl.value,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    _barWidth = constraints.maxWidth;
                    return SizedBox(
                      height: 44,
                      child: Stack(alignment: Alignment.bottomLeft, children: [
                        Positioned(left: 0, right: 0, bottom: 0,
                          child: Container(height: 3, color: Colors.white30)),
                        Positioned(left: 0, bottom: 0,
                          child: Container(
                            height: 3,
                            width: _currentProgress * _barWidth,
                            color: Colors.white,
                          )),
                        if (_isDragging)
                          Positioned(
                            left: (_currentProgress * _barWidth) - 6,
                            bottom: -1.5,
                            child: Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 3,
                                  offset: Offset(0, 2),
                                )],
                              ),
                            ),
                          ),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Arrow painter for seek preview popup ────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xF21C1C1E);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

// ─── Action button with scale animation on like ───────────────────────────────

class _AnimatedActionBtn extends StatefulWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  const _AnimatedActionBtn({required this.child, required this.label, required this.onTap});

  @override
  State<_AnimatedActionBtn> createState() => _AnimatedActionBtnState();
}

class _AnimatedActionBtnState extends State<_AnimatedActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    lowerBound: 1.0,
    upperBound: 1.3,
  );

  void _onTap() {
    _scale.forward().then((_) => _scale.reverse());
    widget.onTap();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
        if (widget.label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600, fontFamily: 'Outfit',
                  shadows: [Shadow(blurRadius: 4)])),
        ],
      ]),
    );
  }
}

// ─── Plain action button ──────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.child, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        child,
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600, fontFamily: 'Outfit',
                  shadows: [Shadow(blurRadius: 4)])),
        ],
      ]),
    );
  }
}

// ─── Comment footer bar ───────────────────────────────────────────────────────

class _CommentFooter extends StatelessWidget {
  final VoidCallback? onTap;
  const _CommentFooter({this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      color: const Color(0xFF0D1017),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: const Text('Add a comment...',
              style: TextStyle(color: Colors.white60, fontFamily: 'Outfit', fontSize: 14)),
        ),
      ),
    );
  }
}

