import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../widgets/common/post_card.dart';
import '../../widgets/common/verification_badge.dart';

// ─── Comment model ──────────────────────────────────────────────────────────

class _Comment {
  final String id;
  final String userId;
  final String username;
  final String? profilePic;
  final String text;
  int likes;
  bool isLiked;
  final DateTime createdAt;
  final bool isVerified;
  final Map<String, dynamic>? badgeData;
  final String? parentId;
  List<_Comment> replies;

  _Comment({
    required this.id,
    required this.userId,
    required this.username,
    this.profilePic,
    required this.text,
    required this.likes,
    required this.isLiked,
    required this.createdAt,
    this.isVerified = false,
    this.badgeData,
    this.parentId,
    List<_Comment>? replies,
  }) : replies = replies ?? [];

  factory _Comment.fromJson(Map<String, dynamic> j) {
    final repliesRaw = j['replies'] as List<dynamic>? ?? [];
    return _Comment(
      id: (j['id'] ?? '').toString(),
      userId: (j['user_id'] ?? '').toString(),
      username: (j['username'] ?? '') as String,
      profilePic: j['profile_pic'] as String?,
      text: (j['comment'] ?? '') as String,
      likes: (j['likes'] ?? 0) as int,
      isLiked: j['isLiked'] == true,
      createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ?? DateTime.now(),
      isVerified: j['is_verified'] == true,
      badgeData: j['verification_badge'] as Map<String, dynamic>?,
      parentId: j['parent_id']?.toString(),
      replies: repliesRaw
          .whereType<Map<String, dynamic>>()
          .map(_Comment.fromJson)
          .toList(),
    );
  }
}

// ─── Tap recogniser helper ──────────────────────────────────────────────────
TapGestureRecognizer _tapRec(VoidCallback cb) => TapGestureRecognizer()..onTap = cb;

// ─── Screen ─────────────────────────────────────────────────────────────────

class PostViewScreen extends ConsumerStatefulWidget {
  final String suffix;
  final String? highlightCommentId;
  const PostViewScreen({
    super.key,
    required this.suffix,
    this.highlightCommentId,
  });

  @override
  ConsumerState<PostViewScreen> createState() => _PostViewScreenState();
}

class _PostViewScreenState extends ConsumerState<PostViewScreen> {
  static const _storage = FlutterSecureStorage();

  // ── Data ───────────────────────────────────────────────────────────────────
  String? _currentUserId;
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _currentUserData;
  List<_Comment> _comments = [];

  // ── Flags ──────────────────────────────────────────────────────────────────
  bool _loadingPost = true;
  bool _loadingComments = false;
  bool _posting = false;
  bool _deletingComment = false;

  // ── Post status ────────────────────────────────────────────────────────────
  bool _isPostRemoved = false;
  String? _removalReason;
  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;
  String? _error;

  // ── Comment input ──────────────────────────────────────────────────────────
  _Comment? _replyingTo;
  final _commentCtrl  = TextEditingController();
  final _commentFocus = FocusNode();
  int _cursorPos = 0;

  // ── Mention ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions = false;
  Timer? _mentionTimer;

  // ── Reply expand ───────────────────────────────────────────────────────────
  final Map<String, bool> _expandedReplies = {};

  // ── Highlight ──────────────────────────────────────────────────────────────
  String? _highlightedCommentId;
  Timer? _highlightTimer;

  // ── Delete dialog ──────────────────────────────────────────────────────────
  _Comment? _commentToDelete;
  bool _showDeleteDialog = false;

  // ── Like debounce ──────────────────────────────────────────────────────────
  final Set<String> _likingComments = {};

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _highlightedCommentId = widget.highlightCommentId;
    _init();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    _mentionTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    final uid = await _storage.read(key: 'uid');
    if (mounted) setState(() => _currentUserId = uid);
    await _loadPost();
    if (uid != null) {
      try {
        final res = await dioClient.get('/v1/user/$uid');
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic> && mounted) {
          setState(() => _currentUserData = data);
        }
      } catch (_) {}
    }
  }

  // ── Load post ──────────────────────────────────────────────────────────────
  Future<void> _loadPost() async {
    if (!mounted) return;
    setState(() { _loadingPost = true; _error = null; });
    try {
      final uid = _currentUserId ?? await _storage.read(key: 'uid');
      final res = await dioClient.get(
        '/v1/posts/share/${widget.suffix}',
        queryParameters: uid != null ? {'userId': uid} : null,
      );
      final posts = res.data['data']?['posts'] ?? res.data['posts'];
      if (posts is List && posts.isNotEmpty) {
        final postData = posts[0] as Map<String, dynamic>;

        if ((postData['removal_status'] as String?) == 'removed') {
          setState(() {
            _isPostRemoved = true;
            _removalReason = (postData['removal_reason'] as String?) ??
                'This post was removed for violating community guidelines';
          });
        }

        setState(() => _post = postData);

        final authorId = (postData['user_id'] ?? '').toString();
        if (uid != null && authorId.isNotEmpty && authorId != uid) {
          try {
            final blockRes = await dioClient.get('/v1/block/check',
                queryParameters: {'blocker_id': uid, 'blocked_id': authorId});
            final bd = blockRes.data['data'];
            if (mounted) {
              setState(() {
                _iBlockedThem = bd?['i_blocked_them'] == true;
                _theyBlockedMe = bd?['they_blocked_me'] == true;
              });
              if (_theyBlockedMe) return;
            }
          } catch (_) {}
        }

        await _loadComments((postData['id'] ?? '').toString());
      } else {
        if (mounted) setState(() => _error = 'Post not found');
      }
    } catch (e) {
      if (!mounted) return;
      final code = _httpCode(e);
      if (code == 404) {
        setState(() => _error = 'Post not found');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) context.pop();
        });
      } else if (code == 410) {
        setState(() {
          _isPostRemoved = true;
          _removalReason = 'This post was removed for violating community guidelines';
        });
      } else {
        setState(() => _error = 'Failed to load post');
      }
    } finally {
      if (mounted) setState(() => _loadingPost = false);
    }
  }

  int? _httpCode(Object e) {
    try {
      // ignore: avoid_dynamic_calls
      return (e as dynamic).response?.statusCode as int?;
    } catch (_) {
      return null;
    }
  }

  // ── Load comments ──────────────────────────────────────────────────────────
  Future<void> _loadComments(String postId) async {
    if (postId.isEmpty || !mounted) return;
    setState(() => _loadingComments = true);
    try {
      final uid = _currentUserId;
      final res = await dioClient.get(
        '/v1/comments/$postId',
        queryParameters: uid != null ? {'userId': uid} : null,
      );
      final raw = res.data['data']?['comments'] ?? res.data['comments'];
      if (raw is List && mounted) {
        setState(() {
          _comments = raw
              .whereType<Map<String, dynamic>>()
              .map(_Comment.fromJson)
              .toList();
        });
        _scheduleHighlightClear();
      }
    } catch (_) {
      if (mounted) setState(() => _comments = []);
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _scheduleHighlightClear() {
    if (_highlightedCommentId == null) return;
    for (final c in _comments) {
      if (c.replies.any((r) => r.id == _highlightedCommentId)) {
        _expandedReplies[c.id] = true;
      }
    }
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedCommentId = null);
    });
  }

  // ── Post comment ───────────────────────────────────────────────────────────
  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _posting || _post == null) return;
    setState(() => _posting = true);
    final postId = (_post!['id'] ?? '').toString();
    try {
      final payload = {
        'postId': postId,
        'userId': _currentUserId,
        'comment': text,
        if (_replyingTo != null) 'parentId': _replyingTo!.id,
      };
      final res = await dioClient.post('/v1/comments', data: payload);
      if (res.data['message'] == 'Comment added successfully') {
        final newData = (res.data['data'] as Map<String, dynamic>?) ?? {};
        final newComment = _Comment(
          id: (newData['id'] ?? '').toString(),
          userId: (newData['user_id'] ?? _currentUserId ?? '').toString(),
          username: (newData['username'] ?? _currentUserData?['username'] ?? '') as String,
          profilePic: newData['profile_pic'] as String? ??
              _currentUserData?['profile_pic'] as String?,
          text: (newData['comment'] ?? text) as String,
          likes: 0,
          isLiked: false,
          createdAt: DateTime.tryParse((newData['created_at'] ?? '') as String) ?? DateTime.now(),
          isVerified: _currentUserData?['is_verified'] == true,
        );
        if (mounted) {
          setState(() {
            if (_replyingTo != null) {
              final idx = _comments.indexWhere((c) => c.id == _replyingTo!.id);
              if (idx >= 0) {
                _comments[idx].replies = [..._comments[idx].replies, newComment];
                _expandedReplies[_replyingTo!.id] = true;
              }
            } else {
              _comments = [newComment, ..._comments];
            }
            _replyingTo = null;
          });
          _commentCtrl.clear();
          _commentFocus.unfocus();
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // ── Like comment ───────────────────────────────────────────────────────────
  Future<void> _likeComment(String commentId) async {
    if (_likingComments.contains(commentId) || _currentUserId == null) return;
    _likingComments.add(commentId);

    bool? prevLiked;
    int? prevCount;

    setState(() {
      _updateCommentLike(commentId, (c) {
        prevLiked = c.isLiked;
        prevCount = c.likes;
        c.isLiked = !c.isLiked;
        c.likes   = c.isLiked ? c.likes + 1 : (c.likes - 1).clamp(0, c.likes);
      });
    });

    try {
      await dioClient.post('/v1/like/comment/toggle',
          data: {'commentId': commentId, 'userId': _currentUserId});
    } catch (_) {
      if (mounted && prevLiked != null) {
        setState(() {
          _updateCommentLike(commentId, (c) {
            c.isLiked = prevLiked!;
            c.likes   = prevCount ?? c.likes;
          });
        });
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 300));
      _likingComments.remove(commentId);
    }
  }

  void _updateCommentLike(String id, void Function(_Comment c) fn) {
    for (final c in _comments) {
      if (c.id == id) { fn(c); return; }
      for (final r in c.replies) {
        if (r.id == id) { fn(r); return; }
      }
    }
  }

  // ── Delete comment ─────────────────────────────────────────────────────────
  Future<void> _deleteComment() async {
    if (_commentToDelete == null || _deletingComment) return;
    setState(() => _deletingComment = true);
    try {
      final res = await dioClient.delete(
        '/v1/comments/${_commentToDelete!.id}',
        data: {'userId': _currentUserId},
      );
      if (res.data['success'] == true && mounted) {
        final isReply = _commentToDelete!.parentId != null;
        setState(() {
          if (isReply) {
            for (final c in _comments) {
              c.replies.removeWhere((r) => r.id == _commentToDelete!.id);
            }
          } else {
            _comments.removeWhere((c) => c.id == _commentToDelete!.id);
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() {
          _deletingComment = false;
          _showDeleteDialog = false;
          _commentToDelete  = null;
        });
      }
    }
  }

  // ── Mention search ─────────────────────────────────────────────────────────
  void _onCommentChanged(String text) {
    _mentionTimer?.cancel();
    final before = text.substring(0, _cursorPos.clamp(0, text.length));
    final match  = RegExp(r'@([a-zA-Z0-9_.]*)$').firstMatch(before);
    if (match != null) {
      _mentionTimer = Timer(const Duration(milliseconds: 200), () async {
        try {
          final res = await dioClient.get('/v1/user/mention-search',
              queryParameters: {'q': match.group(1), 'limit': 4});
          if (mounted && res.data['success'] == true) {
            final users = (res.data['users'] as List<dynamic>?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [];
            setState(() { _mentionSuggestions = users; _showMentions = users.isNotEmpty; });
          }
        } catch (_) {
          if (mounted) setState(() { _mentionSuggestions = []; _showMentions = false; });
        }
      });
    } else {
      setState(() { _showMentions = false; _mentionSuggestions = []; });
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final text   = _commentCtrl.text;
    final cursor = _cursorPos.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after  = text.substring(cursor);
    final match  = RegExp(r'@([a-zA-Z0-9_.]*)$').firstMatch(before);
    if (match != null) {
      final username = user['username'] as String;
      final newText  = '${before.substring(0, match.start)}@$username $after';
      _commentCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: match.start + username.length + 2),
      );
    }
    setState(() { _showMentions = false; _mentionSuggestions = []; });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _navigateToProfile(String userId) {
    if (userId.isEmpty) return;
    if (userId == _currentUserId) context.push('/profile');
    else context.push('/user/$userId');
  }

  // ── Start reply ────────────────────────────────────────────────────────────
  void _startReply(_Comment comment, {bool isReply = false}) {
    _Comment target;
    if (isReply && comment.parentId != null) {
      target = _comments.firstWhere((c) => c.id == comment.parentId, orElse: () => comment);
      _commentCtrl.text = '@${comment.username} ';
    } else {
      target = comment;
      _commentCtrl.text = '';
    }
    setState(() => _replyingTo = target);
    Future.delayed(const Duration(milliseconds: 100), _commentFocus.requestFocus);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loadingPost) return _buildFullScreenState(_buildLoadingBody(c), c);
    if (_isPostRemoved && _post == null) return _buildFullScreenState(_buildRemovedBody(c), c);
    if (_theyBlockedMe) return _buildFullScreenState(_buildBlockedBody(c), c);
    if (_error != null || _post == null) return _buildFullScreenState(_buildErrorBody(c), c);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _buildHeader(c),
            Expanded(
              child: ListView(children: [
                if (_isPostRemoved) _buildRemovedBanner(),
                PostCard(
                  post: _post!,
                  currentUserId: _currentUserId,
                  isRemoved: _isPostRemoved,
                  onLikeUpdate: (id, liked, count) {
                    if (mounted) setState(() { _post!['isLiked'] = liked; _post!['likes'] = count; });
                  },
                  onCommentUpdate: (_, count) {
                    if (mounted) setState(() => _post!['comments'] = count);
                  },
                  onCommentTap: (_) => _commentFocus.requestFocus(),
                ),
                _buildCommentsSection(c),
              ]),
            ),
            if (_replyingTo != null && !_isPostRemoved) _buildReplyIndicator(c),
            if (_showMentions && _mentionSuggestions.isNotEmpty && !_isPostRemoved)
              _buildMentionSuggestions(c),
            _buildBottomBar(c),
          ]),
          if (_showDeleteDialog) _buildDeleteDialogOverlay(c),
        ]),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        Expanded(
          child: Text(
            'Post',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.text, fontSize: 18,
                fontFamily: 'Outfit', fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 48),
      ]),
    );
  }

  // ── Removed banner ─────────────────────────────────────────────────────────
  Widget _buildRemovedBanner() {
    return Container(
      color: const Color(0xFFE74C3C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('This post has been removed',
              style: TextStyle(color: Colors.white, fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  // ── Comments section ───────────────────────────────────────────────────────
  Widget _buildCommentsSection(ThemeColors c) {
    return Container(
      color: c.background,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
          ),
          child: Text(
            'Comments (${_comments.length})',
            style: TextStyle(color: c.text, fontSize: 16,
                fontFamily: 'Outfit', fontWeight: FontWeight.w600),
          ),
        ),
        if (_loadingComments)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_comments.isEmpty)
          _buildNoComments(c)
        else
          ..._buildFlatCommentList(c),
        const SizedBox(height: 24),
      ]),
    );
  }

  List<Widget> _buildFlatCommentList(ThemeColors c) {
    final widgets = <Widget>[];
    for (final comment in _comments) {
      final hasReplies = comment.replies.isNotEmpty;
      final isExpanded = _expandedReplies[comment.id] == true;

      widgets.add(_buildCommentItem(comment, isReply: false,
          hasExpandedReplies: hasReplies && isExpanded, c: c));

      if (hasReplies && !isExpanded) {
        widgets.add(_buildToggleRepliesButton(comment, expand: true, c: c));
      }
      if (hasReplies && isExpanded) {
        for (final reply in comment.replies) {
          widgets.add(_buildCommentItem(reply, isReply: true, c: c));
        }
        widgets.add(_buildToggleRepliesButton(comment, expand: false, c: c));
      }
    }
    return widgets;
  }

  Widget _buildToggleRepliesButton(_Comment parent, {
    required bool expand,
    required ThemeColors c,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardBackground,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      padding: const EdgeInsets.only(left: 72, right: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expandedReplies[parent.id] = expand),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(width: 24, height: 1, color: c.border,
                margin: const EdgeInsets.only(right: 8)),
            Text(
              expand
                  ? 'View ${parent.replies.length} ${parent.replies.length == 1 ? "reply" : "replies"}'
                  : 'Hide replies',
              style: TextStyle(color: c.textTertiary, fontSize: 13,
                  fontFamily: 'Outfit', fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCommentItem(_Comment comment, {
    required bool isReply,
    bool hasExpandedReplies = false,
    required ThemeColors c,
  }) {
    final isHighlighted = _highlightedCommentId == comment.id;
    final isOwnComment  = comment.userId == _currentUserId;

    BoxDecoration decoration;
    if (isHighlighted) {
      decoration = BoxDecoration(
        color: c.primary.withValues(alpha: 0.15),
        border: Border(
          left:   BorderSide(color: c.primary, width: 3),
          bottom: BorderSide(color: c.border, width: 0.5),
        ),
      );
    } else if (hasExpandedReplies) {
      decoration = BoxDecoration(color: isReply ? c.cardBackground : c.background);
    } else {
      decoration = BoxDecoration(
        color: isReply ? c.cardBackground : c.background,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      );
    }

    return GestureDetector(
      onLongPress: isOwnComment
          ? () => setState(() { _commentToDelete = comment; _showDeleteDialog = true; })
          : null,
      child: Container(
        decoration: decoration,
        padding: EdgeInsets.only(
          left: isReply ? 28 : 16,
          right: 16, top: 12, bottom: 12,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => _navigateToProfile(comment.userId),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: c.border,
              backgroundImage: comment.profilePic != null
                  ? CachedNetworkImageProvider(comment.profilePic!)
                  : null,
              child: comment.profilePic == null
                  ? Text(
                      comment.username.isNotEmpty ? comment.username[0].toUpperCase() : '?',
                      style: TextStyle(color: c.text, fontFamily: 'Outfit'),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(comment.userId),
                  child: Text(comment.username,
                      style: TextStyle(color: c.text, fontSize: 14,
                          fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                ),
                if (comment.isVerified) ...[
                  const SizedBox(width: 4),
                  VerificationBadge(isVerified: true, badge: comment.badgeData, size: 14),
                ],
                const SizedBox(width: 8),
                Text(timeago.format(comment.createdAt),
                    style: TextStyle(color: c.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
              ]),
              const SizedBox(height: 4),
              _buildCommentText(comment.text, c),
              const SizedBox(height: 6),
              if (!isOwnComment)
                GestureDetector(
                  onTap: () => _startReply(comment, isReply: isReply),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Reply',
                        style: TextStyle(color: c.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
                  ),
                ),
            ]),
          ),

          // Like
          GestureDetector(
            onTap: () => _likeComment(comment.id),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: comment.isLiked ? c.likeColor : c.textTertiary,
                ),
                if (comment.likes > 0)
                  Text('${comment.likes}',
                      style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'Outfit')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCommentText(String text, ThemeColors c) {
    final parts   = <InlineSpan>[];
    final pattern = RegExp(r'@([a-zA-Z0-9_.]+)');
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) parts.add(TextSpan(text: text.substring(last, m.start)));
      final username = m.group(1)!;
      parts.add(TextSpan(
        text: '@$username',
        style: TextStyle(color: c.primary, fontFamily: 'Outfit',
            fontWeight: FontWeight.w600, fontSize: 14),
        recognizer: _tapRec(() async {
          try {
            final res = await dioClient.get('/v1/user/find/$username');
            final uid = ((res.data['data'] ?? res.data) as Map<String, dynamic>?)?['id']?.toString();
            if (uid != null && mounted) _navigateToProfile(uid);
          } catch (_) {}
        }),
      ));
      last = m.end;
    }
    if (last < text.length) parts.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(
        children: parts,
        style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit', height: 1.43),
      ),
    );
  }

  Widget _buildNoComments(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(children: [
        Icon(Icons.chat_bubble_outline, size: 48, color: c.textTertiary),
        const SizedBox(height: 16),
        Text('No comments yet', style: TextStyle(color: c.textTertiary, fontSize: 16,
            fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Be the first to comment',
            style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
      ]),
    );
  }

  // ── Reply indicator ────────────────────────────────────────────────────────
  Widget _buildReplyIndicator(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Text('Replying to ${_replyingTo!.username}',
              style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
        ),
        GestureDetector(
          onTap: () => setState(() { _replyingTo = null; _commentCtrl.text = ''; }),
          child: Icon(Icons.close, color: c.textTertiary, size: 20),
        ),
      ]),
    );
  }

  // ── Mention suggestions ────────────────────────────────────────────────────
  Widget _buildMentionSuggestions(ThemeColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _mentionSuggestions.map((user) => GestureDetector(
          onTap: () => _insertMention(user),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border, width: 0.5))),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.border,
                backgroundImage: (user['profile_pic'] as String?) != null
                    ? CachedNetworkImageProvider(user['profile_pic'] as String)
                    : null,
                child: (user['profile_pic'] as String?) == null
                    ? Text(
                        ((user['name'] ?? user['username'] ?? '?') as String)[0].toUpperCase(),
                        style: TextStyle(color: c.text, fontFamily: 'Outfit'),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((user['name'] ?? '') as String,
                    style: TextStyle(color: c.text, fontSize: 14,
                        fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                Text('@${(user['username'] ?? '') as String}',
                    style: TextStyle(color: c.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
              ]),
            ]),
          ),
        )).toList(),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(ThemeColors c) {
    if (_isPostRemoved) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: Color(0xFFE74C3C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Removal Reason:',
                  style: TextStyle(color: Color(0xFFE74C3C), fontSize: 13,
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_removalReason ?? '',
                  style: TextStyle(color: c.textTertiary, fontSize: 13,
                      fontFamily: 'Outfit', height: 1.4)),
            ]),
          ),
        ]),
      );
    }

    if (_iBlockedThem) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(children: [
          Icon(Icons.block, color: c.textTertiary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('You have blocked this user. Unblock to comment.',
                style: TextStyle(color: c.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: c.border,
          backgroundImage: (_currentUserData?['profile_pic'] as String?) != null
              ? CachedNetworkImageProvider(_currentUserData!['profile_pic'] as String)
              : null,
          child: (_currentUserData?['profile_pic'] as String?) == null
              ? Icon(Icons.person, color: c.textTertiary, size: 18)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            focusNode: _commentFocus,
            maxLines: null,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: _replyingTo != null ? 'Reply...' : 'Add a comment...',
              hintStyle: TextStyle(color: c.textTertiary, fontFamily: 'Outfit', fontSize: 14),
              filled: true,
              fillColor: c.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: c.primary)),
              counterText: '',
            ),
            style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14),
            onChanged: (v) { _onCommentChanged(v); setState(() {}); },
            onTap: () => setState(() {}),
          ),
        ),
        if (_commentCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _postComment,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _posting
                  ? SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                  : Icon(Icons.send, color: c.primary, size: 24),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Delete dialog overlay ──────────────────────────────────────────────────
  Widget _buildDeleteDialogOverlay(ThemeColors c) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() { _showDeleteDialog = false; _commentToDelete = null; }),
        child: Container(
          color: c.overlay,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Delete Comment',
                      style: TextStyle(color: c.text, fontSize: 18,
                          fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to delete this comment? This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textTertiary, fontSize: 14,
                        fontFamily: 'Outfit', height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _showDeleteDialog = false;
                          _commentToDelete  = null;
                        }),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                              color: c.cardBackground,
                              borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text('Cancel',
                              style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _deleteComment,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                              color: c.danger,
                              borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: _deletingComment
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Delete',
                                  style: TextStyle(color: Colors.white, fontFamily: 'Outfit',
                                      fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Full-screen state helpers ──────────────────────────────────────────────
  Widget _buildFullScreenState(Widget body, ThemeColors c) {
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(c),
        Expanded(child: body),
      ])),
    );
  }

  Widget _buildLoadingBody(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: c.primary, strokeWidth: 2),
        const SizedBox(height: 12),
        Text('Loading post...',
            style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
      ]),
    );
  }

  Widget _buildRemovedBody(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.block, size: 64, color: c.textTertiary),
        const SizedBox(height: 16),
        Text('Post Removed',
            style: TextStyle(color: c.text, fontSize: 20,
                fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'This post was removed for violating community guidelines',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textTertiary, fontSize: 14,
                fontFamily: 'Outfit', height: 1.5),
          ),
        ),
      ]),
    );
  }

  Widget _buildBlockedBody(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.block, size: 64, color: c.textTertiary),
        const SizedBox(height: 16),
        Text('Content Unavailable',
            style: TextStyle(color: c.text, fontSize: 20,
                fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('This post is not available to you.',
            style: TextStyle(color: c.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
      ]),
    );
  }

  Widget _buildErrorBody(ThemeColors c) {
    return Center(
      child: Text(_error ?? 'Post not found',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textTertiary, fontSize: 18,
              fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
    );
  }
}
