import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import 'verification_badge.dart';

// ─── Content parsing ────────────────────────────────────────────────────────
enum _PartType { text, link, mention, hashtag }

class _ContentPart {
  final _PartType type;
  final String content;
  const _ContentPart(this.type, this.content);
}

List<_ContentPart> _parseContent(String text) {
  final parts = <_ContentPart>[];
  final pattern = RegExp(r'(https?://[^\s]+)|@([a-zA-Z0-9_]+)|#([a-zA-Z0-9_]+)');
  int last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) parts.add(_ContentPart(_PartType.text, text.substring(last, m.start)));
    if (m.group(1) != null) {
      parts.add(_ContentPart(_PartType.link, m.group(1)!));
    } else if (m.group(2) != null) {
      parts.add(_ContentPart(_PartType.mention, '@${m.group(2)}'));
    } else if (m.group(3) != null) {
      parts.add(_ContentPart(_PartType.hashtag, '#${m.group(3)}'));
    }
    last = m.end;
  }
  if (last < text.length) parts.add(_ContentPart(_PartType.text, text.substring(last)));
  return parts;
}

// ─── Aspect-ratio helper ────────────────────────────────────────────────────
double _aspectRatioFromString(String? s) {
  if (s == null || s.isEmpty) return 1.0;
  switch (s) {
    case '9:16': return 9 / 16;
    case '16:9': return 16 / 9;
    case '4:5':  return 4 / 5;
    case '1:1':  return 1.0;
    default:
      final p = s.split(':');
      if (p.length == 2) {
        final w = double.tryParse(p[0]), h = double.tryParse(p[1]);
        if (w != null && h != null && h != 0) return w / h;
      }
      return 1.0;
  }
}

double _mediaAspectRatio(Map<String, dynamic> item) {
  final w = (item['width'] as num?)?.toDouble();
  final h = (item['height'] as num?)?.toDouble();
  if (w != null && h != null && h > 0) return w / h;
  return _aspectRatioFromString(item['aspectRatio'] as String?);
}

// ─── PostCard widget ─────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? currentUserId;
  final bool isRemoved;
  final void Function(String postId, bool isLiked, int count)? onLikeUpdate;
  final void Function(String postId, int count)? onCommentUpdate;
  final void Function(String postId, String userId, Map<String, dynamic> extra)? onShowMoreMenu;
  /// Called when the comment button is tapped. When provided, skips default navigation.
  final void Function(String postId)? onCommentTap;

  const PostCard({
    super.key,
    required this.post,
    this.currentUserId,
    this.isRemoved = false,
    this.onLikeUpdate,
    this.onCommentUpdate,
    this.onShowMoreMenu,
    this.onCommentTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late int _likes;
  late bool _isLiked;
  late int _comments;
  late bool _isFollowing;
  bool _liking = false;
  bool _expanded = false;
  bool _showReadMore = false;
  int _mediaIndex = 0;

  // Double-tap heart
  late AnimationController _heartCtrl;
  bool _showHeart = false;
  int? _lastTap;
  Timer? _singleTapTimer;

  // View tracking
  Timer? _viewTimer;
  bool _viewTracked = false;

  Map<String, dynamic> get _p => widget.post;
  List<dynamic> get _media {
    final m = _p['media'];
    if (m is List && m.isNotEmpty) return m;
    final i = _p['images'];
    if (i is List && i.isNotEmpty) return i;
    return [];
  }

  Map<String, dynamic>? get _user => _p['user'] as Map<String, dynamic>?;
  String get _postId => (_p['id'] ?? '').toString();
  String get _userId => (_user?['id'] ?? _p['user_id'] ?? '').toString();

  List<Map<String, dynamic>> get _mediaItems {
    return _media.map<Map<String, dynamic>>((item) {
      if (item is String) return {'type': 'image', 'url': item, 'aspectRatio': '1:1', 'width': 600, 'height': 600};
      final m = Map<String, dynamic>.from(item as Map);
      if (m['width'] != null && m['height'] != null) {
        m['aspectRatio'] = '${m['width']}:${m['height']}';
      } else {
        m['aspectRatio'] ??= '1:1';
      }
      return m;
    }).toList();
  }

  List<_ContentPart>? _parsedContent;

  @override
  void initState() {
    super.initState();
    _likes    = (_p['likes'] ?? 0) as int;
    _isLiked  = _p['isLiked'] == true;
    _comments = (_p['comments'] ?? 0) as int;
    _isFollowing = _p['isFollowing'] == true;

    final text = (_p['content'] ?? '') as String;
    if (text.isNotEmpty) _parsedContent = _parseContent(text);

    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _heartCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 800), () => _heartCtrl.reverse());
      }
      if (s == AnimationStatus.dismissed) {
        if (mounted) setState(() => _showHeart = false);
      }
    });

    _startViewTimer();
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _singleTapTimer?.cancel();
    _viewTimer?.cancel();
    super.dispose();
  }

  void _startViewTimer() {
    _viewTimer = Timer(const Duration(seconds: 3), () {
      if (!_viewTracked && mounted) {
        _viewTracked = true;
        _trackView();
      }
    });
  }

  Future<void> _trackView() async {
    try {
      await dioClient.post('/v1/engagement/track-view', data: {'postId': _postId});
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_liking || widget.isRemoved) return;
    final prev = _isLiked;
    final prevCount = _likes;
    final newLiked = !prev;
    final newCount = newLiked ? prevCount + 1 : (prevCount - 1).clamp(0, prevCount);
    setState(() { _liking = true; _isLiked = newLiked; _likes = newCount; });
    try {
      final res = await dioClient.post('/v1/like/post/toggle',
          data: {'postId': _postId, 'userId': widget.currentUserId});
      final action = res.data['action'];
      final finalLiked = (action == 'liked' || action == true) ? true
          : (action == 'unliked' || action == false) ? false
          : (res.statusCode == 201) ? true
          : (res.statusCode == 200) ? false
          : newLiked;
      if (mounted) setState(() => _isLiked = finalLiked);
      widget.onLikeUpdate?.call(_postId, finalLiked, newCount);
    } catch (_) {
      if (mounted) setState(() { _isLiked = prev; _likes = prevCount; });
      widget.onLikeUpdate?.call(_postId, prev, prevCount);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null || widget.currentUserId == _userId) return;
    setState(() => _isFollowing = !_isFollowing);
    try {
      await dioClient.post('/v1/followers/toggle', data: {'followingId': _userId});
    } catch (_) {
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    }
  }

  void _handleImageTap(int index) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const doubleTapMs = 300;
    if (_lastTap != null && now - _lastTap! < doubleTapMs) {
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      if (!_isLiked && !_liking) _toggleLike();
      _triggerHeart();
      _lastTap = null;
      return;
    }
    _lastTap = now;
    _singleTapTimer?.cancel();
    _singleTapTimer = Timer(const Duration(milliseconds: doubleTapMs), () {
      _openImageViewer(index);
      _lastTap = null;
    });
  }

  void _triggerHeart() {
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(c),
        if ((_p['content'] as String? ?? '').isNotEmpty) _buildContent(c),
        if (_mediaItems.isNotEmpty) _buildMediaSection(c),
        _buildActions(c),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeColors c) {
    final name      = _user?['name'] ?? 'Unknown';
    final pic       = _user?['profile_pic'] as String?;
    final isVerified = _user?['is_verified'] == true;
    final timeStr   = _p['created_on'] != null
        ? timeago.format(DateTime.tryParse(_p['created_on'] as String) ?? DateTime.now())
        : '';
    final isOwnPost = widget.currentUserId != null && widget.currentUserId == _userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(
          onTap: () => context.push('/user/$_userId'),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: c.border,
            backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null
                ? Text(
                    (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                    style: TextStyle(color: c.text, fontFamily: 'Outfit'),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/user/$_userId'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: TextStyle(color: c.text, fontWeight: FontWeight.w600,
                    fontSize: 14, fontFamily: 'Outfit')),
                if (isVerified) ...[const SizedBox(width: 2), const VerificationBadge(size: 14)],
              ]),
              Text(timeStr, style: TextStyle(color: c.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
            ]),
          ),
        ),
        if (!isOwnPost && !_isFollowing)
          GestureDetector(
            onTap: _toggleFollow,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: c.followButtonBg, borderRadius: BorderRadius.circular(8)),
              child: Text('Follow', style: TextStyle(color: c.followButtonText, fontSize: 14, fontFamily: 'Outfit')),
            ),
          ),
        GestureDetector(
          onTap: () {
            if (widget.onShowMoreMenu != null) {
              widget.onShowMoreMenu!(_postId, _userId, {
                'content': _p['content'],
                'suffix': _p['suffix'],
                'userName': name,
              });
            } else {
              _showMoreMenuSheet(c);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.more_vert, color: c.textTertiary, size: 22),
          ),
        ),
      ]),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────
  Widget _buildContent(ThemeColors c) {
    final hasMedia  = _mediaItems.isNotEmpty;
    final lineLimit = hasMedia ? 2 : 30;
    final rawText   = (_p['content'] ?? '') as String;

    final spans = _parsedContent?.map<InlineSpan>((part) {
      switch (part.type) {
        case _PartType.link:
          return TextSpan(
            text: part.content,
            style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontSize: 14),
            recognizer: _tapRec(() => _openLink(part.content)),
          );
        case _PartType.mention:
          return TextSpan(
            text: part.content,
            style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontSize: 14),
            recognizer: _tapRec(() => _navigateToMention(part.content)),
          );
        case _PartType.hashtag:
          return TextSpan(
            text: part.content,
            style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontSize: 14),
            recognizer: _tapRec(() => _navigateToHashtag(part.content)),
          );
        case _PartType.text:
          return TextSpan(text: part.content);
      }
    }).toList();

    return LayoutBuilder(
      builder: (_, constraints) {
        if (!_showReadMore) {
          final tp = TextPainter(
            text: TextSpan(text: rawText,
                style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', height: 1.43)),
            textDirection: TextDirection.ltr,
            maxLines: lineLimit + 1,
          )..layout(maxWidth: constraints.maxWidth);
          if (tp.didExceedMaxLines) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _showReadMore = true);
            });
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(
                children: spans,
                style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit', height: 1.43),
              ),
              maxLines: _expanded ? null : lineLimit,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (_showReadMore)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: TextStyle(color: c.primaryButton, fontSize: 13,
                        fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }

  // ── Media ─────────────────────────────────────────────────────────────────
  Widget _buildMediaSection(ThemeColors c) {
    final items   = _mediaItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;
    final current = items[_mediaIndex];
    final ar      = _mediaAspectRatio(current);
    double height;
    if (ar <= 0.6) {
      height = (screenW / ar).clamp(0.0, screenW * 1.5);
    } else {
      height = screenW / ar;
    }
    height = height.clamp(160.0, screenW * 1.6);

    return Stack(children: [
      SizedBox(
        height: height,
        child: PageView.builder(
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _mediaIndex = i),
          itemBuilder: (_, i) {
            final item    = items[i];
            final isVideo = (item['type'] as String?) == 'video';
            final url     = (item['url'] ?? '') as String;
            if (isVideo) return _buildVideoThumb(url, c);
            return _buildImageTile(url, i, c);
          },
        ),
      ),
      if (items.length > 1) ...[
        Positioned(
          top: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Text('${_mediaIndex + 1}/${items.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Outfit')),
          ),
        ),
        if (_mediaIndex > 0)
          Positioned(
            left: 12, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _mediaIndex--),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        if (_mediaIndex < items.length - 1)
          Positioned(
            right: 12, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _mediaIndex++),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 16, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(items.length, (i) =>
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == _mediaIndex ? 8 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == _mediaIndex
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          )),
        ),
      ],
      if (_showHeart)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: FadeTransition(
                opacity: _heartCtrl,
                child: ScaleTransition(
                  scale: _heartCtrl.drive(
                      Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.elasticOut))),
                  child: Icon(Icons.favorite, color: c.likeColor, size: 80),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _buildImageTile(String url, int index, ThemeColors c) {
    return GestureDetector(
      onTap: () => _handleImageTap(index),
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: c.border),
          errorWidget: (_, __, ___) => Container(
            color: c.border,
            child: Icon(Icons.broken_image, color: c.textTertiary, size: 40),
          ),
        ),
      ]),
    );
  }

  Widget _buildVideoThumb(String url, ThemeColors c) {
    return GestureDetector(
      onTap: () => context.push('/fullscreen-video?url=${Uri.encodeComponent(url)}'),
      child: Container(
        color: Colors.black,
        child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56)),
      ),
    );
  }

  // ── Actions (pill buttons) ────────────────────────────────────────────────
  Widget _buildActions(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(children: [
        _pillBtn(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: _isLiked ? c.likeColor : c.textTertiary,
          count: _likes,
          liked: _isLiked,
          onTap: widget.isRemoved ? null : _toggleLike,
          c: c,
        ),
        const SizedBox(width: 10),
        _pillBtn(
          icon: Icons.chat_bubble_outline,
          iconColor: c.textTertiary,
          count: _comments,
          liked: false,
          onTap: widget.isRemoved
              ? null
              : () {
                  if (widget.onCommentTap != null) {
                    widget.onCommentTap!(_postId);
                  } else {
                    final suffix = _p['suffix'] as String?;
                    if (suffix != null) {
                      context.push('/post-view/$suffix');
                    } else {
                      context.push('/post/$_postId');
                    }
                  }
                },
          c: c,
        ),
        const SizedBox(width: 10),
        _pillBtn(
          icon: Icons.share_outlined,
          iconColor: c.textTertiary,
          count: (_p['shares'] ?? 0) as int,
          liked: false,
          onTap: widget.isRemoved ? null : () {},
          c: c,
        ),
      ]),
    );
  }

  Widget _pillBtn({
    required IconData icon,
    required Color iconColor,
    required int count,
    required bool liked,
    required ThemeColors c,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: liked ? c.interactionLikedBg : c.interactionButtonBg,
            border: Border.all(
                color: liked ? c.interactionLikedBorder : c.interactionButtonBorder),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 8),
            Text('$count',
                style: TextStyle(
                    color: liked ? c.likeColor : c.textTertiary,
                    fontSize: 12,
                    fontFamily: 'Outfit')),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _openImageViewer(int startIndex) {
    final items = _mediaItems.where((m) => (m['type'] as String?) != 'video').toList();
    if (items.isEmpty) return;
    int imgIdx = 0;
    for (int i = 0; i < startIndex && i < _mediaItems.length; i++) {
      if ((_mediaItems[i]['type'] as String?) != 'video') imgIdx++;
    }
    final urls = items.map((m) => (m['url'] ?? '') as String).toList();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          PhotoViewGallery.builder(
            itemCount: urls.length,
            pageController: PageController(initialPage: imgIdx),
            builder: (_, i) => PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(urls[i])),
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    ));
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  void _navigateToMention(String mention) async {
    final username = mention.replaceFirst('@', '').trim();
    try {
      final res = await dioClient.get('/v1/user/find/$username');
      final uid = (res.data['data'] ?? res.data)?['id'] as String?;
      if (uid != null && mounted) {
        if (uid == widget.currentUserId) {
          context.push('/profile');
        } else {
          context.push('/user/$uid');
        }
      }
    } catch (_) {}
  }

  void _navigateToHashtag(String hashtag) {
    final tag = hashtag.replaceFirst('#', '').trim();
    context.push('/search-result?query=%23$tag');
  }

  void _showMoreMenuSheet(ThemeColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.bottomSheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 8),
        _menuItem(Icons.bookmark_border, 'Save post', () {}, c),
        _menuItem(Icons.flag_outlined, 'Report',
            () => context.push('/report/post/$_postId'), c),
        _menuItem(Icons.block, 'Block user', () {}, c),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, ThemeColors c) {
    return ListTile(
      leading: Icon(icon, color: c.text),
      title: Text(label, style: TextStyle(color: c.text, fontFamily: 'Outfit')),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }
}

// Tap recogniser helper
TapGestureRecognizer _tapRec(VoidCallback cb) => TapGestureRecognizer()..onTap = cb;
