import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/share_bottom_sheet.dart';
import '../../widgets/common/verification_badge.dart';

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

class _MiniScreenState extends ConsumerState<MiniScreen> {
  static const _storage = FlutterSecureStorage();

  final _pageCtrl = PageController();

  List<Map<String, dynamic>> _posts = [];
  int _currentIndex = 0;

  bool _loadingInitial = true;
  bool _loadingMore    = false;
  bool _hasMore        = true;
  int  _page           = 1;

  String? _userId;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentIndex = widget.initialIndex;
    _init();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
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
      final media = p['media'] as List?;
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
      if (mounted) {
        setState(() {
          _posts[index] = {..._posts[index], 'isLiked': finalLiked};
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
    final post         = _posts[index];
    final wasFollowing = post['isFollowing'] == true;
    setState(() => _posts[index] = {...post, 'isFollowing': !wasFollowing});
    try {
      final uid = (post['user'] as Map?)?['id'] ?? post['user_id'];
      await dioClient.post('/v1/followers/toggle', data: {'followingId': uid.toString()});
    } catch (_) {
      if (mounted) setState(() => _posts[index] = {..._posts[index], 'isFollowing': wasFollowing});
    }
  }

  void _openComments(int index) {
    final post   = _posts[index];
    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty) return;
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MiniCommentSheet(postId: postId, currentUserId: _userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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

    final mq     = MediaQuery.of(context);
    final bottom = mq.padding.bottom;
    // Footer height matches RN: 50 + max(bottomInset, 12)
    final footerH = widget.fromVideoClick
        ? 50.0 + bottom.clamp(12.0, double.infinity)
        : 0.0;
    final videoH = mq.size.height - footerH;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        // ── Video pager (fills everything above the footer) ─────────────────
        SizedBox(
          height: videoH,
          child: Stack(children: [
            // PageView fills the video area exactly
            Positioned.fill(
              child: PageView.builder(
                controller: _pageCtrl,
                scrollDirection: Axis.vertical,
                itemCount: _posts.length + (_loadingMore ? 1 : 0),
                onPageChanged: _onPageChanged,
                itemBuilder: (_, i) {
                  if (i >= _posts.length) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  return _MiniItem(
                    post: _posts[i],
                    isActive: i == _currentIndex,
                    currentUserId: _userId,
                    itemHeight: videoH,
                    onLike: () => _toggleLike(i),
                    onComment: () => _openComments(i),
                    onFollow: () => _toggleFollow(i),
                  );
                },
              ),
            ),

            // Header (back + title) — overlaid on top of video
            SafeArea(
              bottom: false,
              child: Padding(
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
              ),
            ),
          ]),
        ),

        // ── Comment footer (sits below video, never overlaps it) ─────────────
        if (widget.fromVideoClick)
          _CommentFooter(
            onTap: _posts.isNotEmpty ? () => _openComments(_currentIndex) : null,
          ),
      ]),
    );
  }
}

// ─── Single reel item ─────────────────────────────────────────────────────────

class _MiniItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFollow;
  /// Height of the video area (excludes the comment footer when present).
  final double itemHeight;

  const _MiniItem({
    required this.post,
    required this.isActive,
    this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onFollow,
    required this.itemHeight,
  });

  @override
  State<_MiniItem> createState() => _MiniItemState();
}

class _MiniItemState extends State<_MiniItem> with TickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  bool _initialized  = false;
  bool _isBuffering  = false;
  bool _holdPaused   = false;

  // Mute
  bool _muted = _globalMuted;

  // Mute indicator overlay (center-screen, 800ms)
  bool _showMuteIndicator = false;
  Timer? _muteIndicatorTimer;

  // Double-tap detection
  int? _lastTapMs;
  Timer? _singleTapTimer;
  static const _doubleTapMs = 300;

  // Hold-to-pause: UI fades out during hold
  late AnimationController _uiOpacityCtrl;
  bool _isHolding = false;
  Timer? _holdTimer;

  // Heart animation (double-tap like)
  late AnimationController _heartCtrl;
  bool _showHeart = false;

  // Video progress for seekbar
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

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
    _initVideo();
  }

  @override
  void didUpdateWidget(_MiniItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive && !_holdPaused) {
        _ctrl?.play();
      } else if (!widget.isActive) {
        _ctrl?.pause();
        _holdPaused = false;
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
    _ctrl?.removeListener(_onVideoListener);
    _ctrl?.dispose();
    super.dispose();
  }

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
        setState(() {
          _initialized  = true;
          _videoDuration = ctrl.value.duration;
        });
        if (widget.isActive && !_holdPaused) ctrl.play();
      }
    });
  }

  void _onVideoListener() {
    if (!mounted || _ctrl == null) return;
    final v = _ctrl!.value;
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

  // ── Tap handling (Instagram-style: 300ms window to detect double-tap) ────

  void _handleTap(TapUpDetails details) {
    // Bottom 200px is the seekbar safe zone — ignore taps there
    if (details.localPosition.dy > widget.itemHeight - 200) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    _singleTapTimer?.cancel();
    _singleTapTimer = null;

    if (_lastTapMs != null && now - _lastTapMs! < _doubleTapMs) {
      // Double tap
      _lastTapMs = null;
      _handleDoubleTap();
      return;
    }

    _lastTapMs = now;
    _singleTapTimer = Timer(const Duration(milliseconds: _doubleTapMs), () {
      if (!mounted) return;
      // Single tap confirmed → toggle mute
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
        setState(() {
          _isHolding = true;
          _holdPaused = true;
        });
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
      // Not a hold — pass to tap handler
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

  // ── Mute button (bottom-left, shown when not holding) ────────────────────

  void _toggleMute() {
    setState(() {
      _muted       = !_muted;
      _globalMuted = _muted;
      _ctrl?.setVolume(_muted ? 0.0 : 1.0);
    });
  }

  // ── Seek ─────────────────────────────────────────────────────────────────

  void _seekTo(Duration position) {
    _ctrl?.seekTo(position);
    setState(() => _videoPosition = position);
  }

  bool get _isLiked      => widget.post['isLiked'] == true;
  bool get _isFollowing  => widget.post['isFollowing'] == true;
  Map<String, dynamic>? get _user => widget.post['user'] as Map<String, dynamic>?;

  @override
  Widget build(BuildContext context) {
    final name      = (_user?['name'] ?? '') as String;
    final pic       = _user?['profile_pic'] as String?;
    final isVerified = _user?['is_verified'] == true;
    final badgeData  = _user?['verification_badge'] as Map<String, dynamic>?;
    final content    = (widget.post['content'] ?? '') as String;
    final likes      = (widget.post['likes'] ?? 0) as int;
    final comments   = (widget.post['comments'] ?? 0) as int;
    final shares     = (widget.post['shares'] ?? 0) as int;
    final userId     = ((_user?['id'] ?? widget.post['user_id']) ?? '').toString();
    final isOwnPost  = widget.currentUserId != null && widget.currentUserId == userId;

    return SizedBox.expand(
      child: GestureDetector(
        onTapDown:    _handlePressDown,
        onTapUp:      _handlePressUp,
        onTapCancel:  _handlePressCancel,
        child: Stack(fit: StackFit.expand, children: [

          // ── Video / thumbnail background ────────────────────────────────
          if (_thumbnail != null)
            CachedNetworkImage(
              imageUrl: _thumbnail!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(color: Colors.black87),

          if (_initialized && _ctrl != null)
            SizedBox.expand(child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:  _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child:  VideoPlayer(_ctrl!),
              ),
            )),

          // ── Buffering spinner ────────────────────────────────────────────
          if (!_initialized || _isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
            ),

          // ── Gradients ────────────────────────────────────────────────────
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

          // ── UI layer (fades during hold) ─────────────────────────────────
          FadeTransition(
            opacity: _uiOpacityCtrl,
            child: Stack(children: [

              // Bottom-left: user info + caption
              Positioned(left: 16, right: 80, bottom: 60,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: () => context.push('/user/$userId'),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                        child: pic == null
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 12))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(name,
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
                          onTap: widget.onFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: const Text('Follow',
                                style: TextStyle(color: Colors.white, fontSize: 12,
                                    fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(content,
                      style: const TextStyle(color: Colors.white, fontSize: 14,
                          fontFamily: 'Outfit', height: 1.4,
                          shadows: [Shadow(blurRadius: 8)]),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ]),
              ),

              // Mute button — bottom-left, above caption area
              Positioned(left: 16, bottom: 110,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Right-side action buttons
              Positioned(right: 12, bottom: 60,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _ActionBtn(
                    child: Icon(
                      Icons.favorite,
                      size: 32,
                      color: _isLiked ? const Color(0xFFFF3040) : Colors.white,
                    ),
                    label: _formatCount(likes),
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 20),
                  _ActionBtn(
                    child: const Icon(Icons.chat_bubble_outline, size: 28, color: Colors.white),
                    label: _formatCount(comments),
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 20),
                  _ActionBtn(
                    child: const Icon(Icons.share, size: 28, color: Colors.white),
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
                  ),
                ]),
              ),
            ]),
          ),

          // ── Seekbar (bottom, always on top) ─────────────────────────────
          if (widget.isActive)
            Positioned(left: 0, right: 0, bottom: 0,
              child: _MiniSeekBar(
                position: _videoPosition,
                duration: _videoDuration,
                thumbnail: _thumbnail,
                onSeek: _seekTo,
              ),
            ),

          // ── Center mute indicator overlay (single-tap feedback) ──────────
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

          // ── Double-tap heart ─────────────────────────────────────────────
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
      ),
    );
  }
}

// ─── Custom seek bar (Instagram Reel style) ───────────────────────────────────

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
    setState(() {
      _isDragging      = true;
      _dragProgress    = p;
      _previewProgress = p;
    });
    widget.onSeek(Duration(
      milliseconds: (p * widget.duration.inMilliseconds).round(),
    ));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || widget.duration == Duration.zero) return;
    final p = (details.localPosition.dx / _barWidth).clamp(0.0, 1.0);
    setState(() {
      _dragProgress    = p;
      _previewProgress = p;
    });
    widget.onSeek(Duration(
      milliseconds: (p * widget.duration.inMilliseconds).round(),
    ));
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_isDragging) return;
    final seekMs = (_dragProgress * widget.duration.inMilliseconds).round();
    widget.onSeek(Duration(milliseconds: seekMs));
    setState(() => _isDragging = false);
    _showFull();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    // Preview popup position (clamped 60..screenW-60)
    final previewX = (_previewProgress * screenW).clamp(60.0, screenW - 60.0);
    final previewDuration = Duration(
      milliseconds: (_previewProgress * widget.duration.inMilliseconds).round(),
    );

    return SizedBox(
      height: 200,
      child: Stack(clipBehavior: Clip.none, children: [

        // Preview popup (shown while dragging)
        if (_isDragging && widget.duration != Duration.zero)
          Positioned(
            bottom: 54,
            left: previewX - 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          imageUrl: widget.thumbnail!,
                          fit: BoxFit.cover,
                          width: 120, height: 160,
                        )
                      : const ColoredBox(color: Colors.black),
                ),
                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    _formatTime(previewDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                // Arrow pointer
                CustomPaint(
                  size: const Size(16, 8),
                  painter: _ArrowPainter(),
                ),
              ],
            ),
          ),

        // Touch area + progress bar track
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onPanStart,
            onHorizontalDragUpdate: _onPanUpdate,
            onHorizontalDragEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: _opacityCtrl,
              builder: (_, __) => Opacity(
                opacity: _opacityCtrl.value,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    _barWidth = constraints.maxWidth;
                    return SizedBox(
                      height: 44,
                      child: Stack(alignment: Alignment.bottomLeft, children: [
                        // Background track
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Container(
                            height: 3,
                            color: Colors.white30,
                          ),
                        ),
                        // Filled progress
                        Positioned(
                          left: 0, bottom: 0,
                          child: Container(
                            height: 3,
                            width: _currentProgress * _barWidth,
                            color: Colors.white,
                          ),
                        ),
                        // Draggable thumb (only when dragging)
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
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

// ─── Action button widget ─────────────────────────────────────────────────────

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
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
              shadows: [Shadow(blurRadius: 4)],
            )),
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
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      color: const Color(0xFF0D1017),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: const Text('Add a comment...',
              style: TextStyle(color: Colors.white60, fontFamily: 'Outfit', fontSize: 14)),
        ),
      ),
    );
  }
}

// ─── Mini comment bottom sheet ────────────────────────────────────────────────

class _MiniCommentSheet extends StatefulWidget {
  final String postId;
  final String? currentUserId;
  const _MiniCommentSheet({required this.postId, this.currentUserId});

  @override
  State<_MiniCommentSheet> createState() => _MiniCommentSheetState();
}

class _MiniCommentSheetState extends State<_MiniCommentSheet> {
  static const _storage = FlutterSecureStorage();

  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;
  String? _userId;
  Map<String, dynamic>? _currentUserData;

  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = widget.currentUserId ?? await _storage.read(key: 'uid');
    setState(() => _userId = uid);
    if (uid != null) {
      try {
        final res  = await dioClient.get('/v1/user/$uid');
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic> && mounted) setState(() => _currentUserData = data);
      } catch (_) {}
    }
    await _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final res = await dioClient.get('/v1/comments/${widget.postId}',
          queryParameters: _userId != null ? {'userId': _userId} : null);
      final raw = res.data['data']?['comments'] ?? res.data['comments'];
      if (raw is List && mounted) {
        setState(() {
          _comments = raw.whereType<Map<String, dynamic>>().toList();
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final res = await dioClient.post('/v1/comments', data: {
        'postId': widget.postId,
        'userId': _userId,
        'comment': text,
        if (_replyingToId != null) 'parentId': _replyingToId,
      });
      if (res.data['message'] == 'Comment added successfully' && mounted) {
        _ctrl.clear();
        setState(() { _replyingToId = null; _replyingToName = null; });
        await _loadComments();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(String commentId, bool current) async {
    if (_userId == null) return;
    setState(() {
      for (final c in _comments) {
        if (c['id'].toString() == commentId) {
          c['isLiked'] = !current;
          c['likes']   = !current
              ? (c['likes'] as int? ?? 0) + 1
              : ((c['likes'] as int? ?? 1) - 1).clamp(0, 999);
          return;
        }
        final replies = c['replies'] as List? ?? [];
        for (final r in replies) {
          if ((r as Map)['id'].toString() == commentId) {
            r['isLiked'] = !current;
            r['likes']   = !current
                ? (r['likes'] as int? ?? 0) + 1
                : ((r['likes'] as int? ?? 1) - 1).clamp(0, 999);
            return;
          }
        }
      }
    });
    try {
      await dioClient.post('/v1/like/comment/toggle',
          data: {'commentId': commentId, 'userId': _userId});
    } catch (_) {
      if (mounted) setState(() {
        for (final c in _comments) {
          if (c['id'].toString() == commentId) {
            c['isLiked'] = current;
            c['likes']   = current
                ? (c['likes'] as int? ?? 1)
                : ((c['likes'] as int? ?? 0) + 1);
            return;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Comments',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white54))
              : _comments.isEmpty
                  ? const Center(child: Text('No comments yet',
                        style: TextStyle(color: Colors.white38, fontFamily: 'Outfit')))
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4),
                      itemCount: _comments.length,
                      itemBuilder: (_, i) => _buildCommentItem(_comments[i], isReply: false),
                    ),
        ),
        if (_replyingToName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white10,
            child: Row(children: [
              Expanded(child: Text('Replying to @$_replyingToName',
                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'Outfit'))),
              GestureDetector(
                onTap: () => setState(() { _replyingToId = null; _replyingToName = null; }),
                child: const Icon(Icons.close, color: Colors.white54, size: 18)),
            ]),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
          color: const Color(0xFF1C1C1E),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: (_currentUserData?['profile_pic'] as String?) != null
                  ? NetworkImage(_currentUserData!['profile_pic'] as String)
                  : null,
              child: (_currentUserData?['profile_pic'] as String?) == null
                  ? const Icon(Icons.person, color: Colors.white54, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                maxLines: null,
                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  hintText: _replyingToName != null ? 'Reply...' : 'Add a comment...',
                  hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Outfit'),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_ctrl.text.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _postComment,
                child: _posting
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white70, size: 24),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, {required bool isReply}) {
    final id         = comment['id']?.toString() ?? '';
    final username   = (comment['username'] ?? '') as String;
    final pic        = comment['profile_pic'] as String?;
    final text       = (comment['comment'] ?? '') as String;
    final likes      = (comment['likes'] ?? 0) as int;
    final isLiked    = comment['isLiked'] == true;
    final isVerified = comment['is_verified'] == true;
    final badgeData  = comment['verification_badge'] as Map<String, dynamic>?;
    final createdAt  = DateTime.tryParse((comment['created_at'] ?? '') as String) ?? DateTime.now();
    final replies    = (comment['replies'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    final userId     = (comment['user_id'] ?? '').toString();
    final isOwn      = userId == _userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.only(left: isReply ? 48 : 16, right: 16, top: 10, bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: pic != null ? NetworkImage(pic) : null,
              child: pic == null
                  ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 11))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(username, style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  if (isVerified) ...[
                    const SizedBox(width: 3),
                    VerificationBadge(isVerified: true, badge: badgeData, size: 12),
                  ],
                  const SizedBox(width: 6),
                  Text(timeago.format(createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Outfit')),
                ]),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: Colors.white70,
                    fontSize: 13, fontFamily: 'Outfit', height: 1.4)),
                const SizedBox(height: 4),
                if (!isOwn)
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToId   = id;
                      _replyingToName = username;
                    }),
                    child: const Text('Reply',
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Outfit')),
                  ),
              ]),
            ),
            GestureDetector(
              onTap: () => _toggleLike(id, isLiked),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isLiked ? const Color(0xFFFF3040) : Colors.white38),
                  if (likes > 0)
                    Text('$likes',
                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Outfit')),
                ]),
              ),
            ),
          ]),
        ),
        for (final reply in replies)
          _buildCommentItem(reply, isReply: true),
        const Divider(color: Colors.white10, height: 1, indent: 16),
      ],
    );
  }
}
