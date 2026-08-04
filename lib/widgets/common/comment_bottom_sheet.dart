import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_colors.dart';
import 'verification_badge.dart';
import 'custom_alert_dialog.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class _Comment {
  final String id;
  final String userId;
  final String username;
  final String? profilePic;
  final String text;
  int likes;
  bool isLiked;
  final String time;
  final bool isVerified;
  final Map<String, dynamic>? verificationBadge;
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
    required this.time,
    this.isVerified = false,
    this.verificationBadge,
    this.parentId,
    List<_Comment>? replies,
  }) : replies = replies ?? [];

  factory _Comment.fromJson(Map<String, dynamic> json, {String? parentId}) => _Comment(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        username: json['username'] ?? '',
        profilePic: json['profile_pic'] as String?,
        text: json['comment'] ?? '',
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        isLiked: json['isLiked'] == true,
        time: json['time'] ?? '',
        isVerified: json['is_verified'] == true,
        verificationBadge: json['verification_badge'] as Map<String, dynamic>?,
        parentId: parentId,
        replies: (json['replies'] as List?)
            ?.map((r) => _Comment.fromJson(r as Map<String, dynamic>,
                parentId: json['id']?.toString()))
            .toList(),
      );
}

class _ReplyTarget {
  final String id;
  final String username;
  const _ReplyTarget({required this.id, required this.username});
}

class _ListItem {
  final _Comment? comment;
  final bool isReply;
  final bool isViewReplies;
  final String? parentId;
  final int replyCount;
  final bool isExpanded;

  const _ListItem._({
    this.comment,
    this.isReply = false,
    this.isViewReplies = false,
    this.parentId,
    this.replyCount = 0,
    this.isExpanded = false,
  });

  factory _ListItem.comment(_Comment c) => _ListItem._(comment: c);
  factory _ListItem.reply(_Comment c) => _ListItem._(comment: c, isReply: true);
  factory _ListItem.viewReplies(String parentId, int count, bool expanded) =>
      _ListItem._(isViewReplies: true, parentId: parentId, replyCount: count, isExpanded: expanded);
}

// ─── Public API ───────────────────────────────────────────────────────────────

void showCommentBottomSheet(
  BuildContext context, {
  required Map<String, dynamic> post,
  required String? currentUserId,
  VoidCallback? onCommentAdded,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentSheet(
      post: post,
      currentUserId: currentUserId,
      onCommentAdded: onCommentAdded,
    ),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _CommentSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final String? currentUserId;
  final VoidCallback? onCommentAdded;

  const _CommentSheet({
    required this.post,
    required this.currentUserId,
    this.onCommentAdded,
  });

  @override
  ConsumerState<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<_CommentSheet>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<_Comment> _comments = [];
  bool _loading = false;
  bool _posting = false;
  bool _loadingMore = false;
  bool _postAuthorBlockedMe = false;
  Map<String, dynamic>? _currentUserData;

  _ReplyTarget? _replyingTo;
  final Map<String, bool> _expandedReplies = {};
  final Map<String, bool> _likingComments = {};
  final Map<String, AnimationController> _heartControllers = {};
  final Map<String, Animation<double>> _heartAnimations = {};

  int _total = 0;
  int _offset = 0;
  final int _limit = 30;
  bool _hasMore = false;

  _Comment? _commentToDelete;

  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentionSuggestions = false;
  Timer? _mentionDebounce;
  int _cursorPos = 0;

  static const _emojis = ['❤️', '🙌', '🔥', '👏', '😢', '😍', '😮', '😂', '😨'];

  String get _postId => widget.post['id']?.toString() ?? '';
  String get _postAuthorId =>
      (widget.post['user_id'] ?? widget.post['user']?['id'])?.toString() ?? '';
  String get _uid =>
      widget.currentUserId ?? ref.read(authProvider).uid ?? '';

  // ── Init / dispose ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _checkBlocked();
    _loadComments();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _mentionDebounce?.cancel();
    for (final c in _heartControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Heart animation per comment ────────────────────────────────────────────

  AnimationController _heartCtrl(String id) {
    return _heartControllers.putIfAbsent(id, () {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      );
      _heartAnimations[id] = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
      ]).animate(ctrl);
      return ctrl;
    });
  }

  Animation<double> _heartAnim(String id) {
    _heartCtrl(id); // ensure created
    return _heartAnimations[id]!;
  }

  void _animateHeart(String id) => _heartCtrl(id).forward(from: 0);

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    if (_uid.isEmpty) return;
    try {
      final res = await dioClient.get('/v1/user/$_uid');
      final data = res.data['data'] ?? res.data;
      if (data is Map && mounted) {
        setState(() => _currentUserData = Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _checkBlocked() async {
    if (_postAuthorId.isEmpty || _postAuthorId == _uid) return;
    try {
      final res = await dioClient.get('/v1/block/check',
          queryParameters: {'blocker_id': _uid, 'blocked_id': _postAuthorId});
      if (mounted) {
        setState(() =>
            _postAuthorBlockedMe = res.data['data']?['they_blocked_me'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadComments({bool loadMore = false}) async {
    if (_postId.isEmpty) return;
    final currentOffset = loadMore ? _offset + _limit : 0;

    if (mounted) setState(() => loadMore ? _loadingMore = true : _loading = true);

    try {
      final res = await dioClient.get(
        '/v1/comments/$_postId',
        queryParameters: {
          if (_uid.isNotEmpty) 'userId': _uid,
          'limit': _limit,
          'offset': currentOffset,
        },
      );

      List<dynamic>? raw;
      Map<String, dynamic>? pagination;

      if (res.data?['data']?['comments'] != null) {
        raw = res.data['data']['comments'] as List;
        pagination = res.data['data']['pagination'] as Map<String, dynamic>?;
      } else if (res.data?['comments'] != null) {
        raw = res.data['comments'] as List;
        pagination = res.data['pagination'] as Map<String, dynamic>?;
      }

      final loaded = (raw ?? [])
          .map((j) => _Comment.fromJson(j as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _comments = loadMore ? [..._comments, ...loaded] : loaded;
          if (pagination != null) {
            _total = (pagination['total'] as num?)?.toInt() ?? _total;
            _hasMore = pagination['hasMore'] == true;
            _offset = currentOffset;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  // ── Post comment ───────────────────────────────────────────────────────────

  Future<void> _postComment() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _posting || _postAuthorBlockedMe) return;

    setState(() => _posting = true);
    try {
      final res = await dioClient.post('/v1/comments', data: {
        'postId': _postId,
        'userId': _uid,
        'comment': text,
        if (_replyingTo != null) 'parentId': _replyingTo!.id,
      });

      if (res.data?['message'] == 'Comment added successfully') {
        final d = res.data['data'] as Map<String, dynamic>;
        final newC = _Comment(
          id: d['id']?.toString() ?? '',
          userId: d['user_id']?.toString() ?? '',
          username: d['username'] ?? '',
          profilePic: d['profile_pic'] as String?,
          text: d['comment'] ?? text,
          likes: 0,
          isLiked: false,
          time: d['time'] ?? 'just now',
          isVerified: _currentUserData?['is_verified'] == true,
          verificationBadge:
              _currentUserData?['verification_badge'] as Map<String, dynamic>?,
        );

        if (mounted) {
          final replyId = _replyingTo?.id;
          setState(() {
            if (replyId != null) {
              _comments = _comments.map((c) {
                if (c.id == replyId) {
                  return _Comment(
                    id: c.id, userId: c.userId, username: c.username,
                    profilePic: c.profilePic, text: c.text,
                    likes: c.likes, isLiked: c.isLiked, time: c.time,
                    isVerified: c.isVerified, verificationBadge: c.verificationBadge,
                    parentId: c.parentId,
                    replies: [...c.replies, newC],
                  );
                }
                return c;
              }).toList();
              _expandedReplies[replyId] = true;
            } else {
              _comments = [newC, ..._comments];
              _total++;
            }
            _replyingTo = null;
            _showMentionSuggestions = false;
            _mentionSuggestions = [];
          });

          _inputCtrl.clear();
          widget.onCommentAdded?.call();

          if (replyId == null && _scrollCtrl.hasClients) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _scrollCtrl.animateTo(0,
                    duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              }
            });
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // ── Reply ──────────────────────────────────────────────────────────────────

  void _handleReply(_Comment comment, {bool isReply = false}) {
    if (isReply && comment.parentId != null) {
      final parent = _comments.firstWhere(
        (c) => c.id == comment.parentId,
        orElse: () => comment,
      );
      setState(() {
        _replyingTo = _ReplyTarget(id: parent.id, username: comment.username);
        _inputCtrl.text = '@${comment.username} ';
        _inputCtrl.selection =
            TextSelection.collapsed(offset: _inputCtrl.text.length);
      });
    } else {
      setState(() {
        _replyingTo = _ReplyTarget(id: comment.id, username: comment.username);
        _inputCtrl.clear();
      });
    }
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _inputCtrl.clear();
      _showMentionSuggestions = false;
    });
  }

  // ── Like ───────────────────────────────────────────────────────────────────

  Future<void> _handleCommentLike(String commentId) async {
    if (_likingComments[commentId] == true) return;
    _animateHeart(commentId);
    setState(() => _likingComments[commentId] = true);

    bool? prevLiked;
    int? prevLikes;

    void mutate(List<_Comment> list) {
      for (final c in list) {
        if (c.id == commentId) {
          prevLiked = c.isLiked;
          prevLikes = c.likes;
          c.isLiked = !c.isLiked;
          c.likes += c.isLiked ? 1 : -1;
          return;
        }
        mutate(c.replies);
      }
    }

    setState(() => mutate(_comments));

    try {
      await dioClient.post('/v1/like/comment/toggle',
          data: {'commentId': commentId, 'userId': _uid});
    } catch (_) {
      void revert(List<_Comment> list) {
        for (final c in list) {
          if (c.id == commentId && prevLiked != null && prevLikes != null) {
            c.isLiked = prevLiked!;
            c.likes = prevLikes!;
            return;
          }
          revert(c.replies);
        }
      }
      if (mounted) setState(() => revert(_comments));
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _likingComments.remove(commentId));
      });
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  void _handleLongPress(_Comment comment) {
    if (comment.userId == _uid) {
      _commentToDelete = comment;
      _showDeleteDialog();
    }
  }

  Future<void> _handleDeleteComment() async {
    if (_commentToDelete == null) return;
    final toDelete = _commentToDelete!;
    _commentToDelete = null;
    try {
      final res = await dioClient.delete(
        '/v1/comments/${toDelete.id}',
        data: {'userId': _uid},
      );
      if (res.data?['success'] == true && mounted) {
        setState(() {
          final isReply = toDelete.parentId != null;
          if (isReply) {
            _comments = _comments.map((c) => _Comment(
                  id: c.id, userId: c.userId, username: c.username,
                  profilePic: c.profilePic, text: c.text,
                  likes: c.likes, isLiked: c.isLiked, time: c.time,
                  isVerified: c.isVerified, verificationBadge: c.verificationBadge,
                  parentId: c.parentId,
                  replies: c.replies.where((r) => r.id != toDelete.id).toList(),
                )).toList();
          } else {
            _comments = _comments.where((c) => c.id != toDelete.id).toList();
            _total = (_total - 1).clamp(0, _total);
          }
        });
        widget.onCommentAdded?.call();
      }
    } catch (_) {}
  }

  // ── Mention search ─────────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    _mentionDebounce?.cancel();
    final cursor = _cursorPos.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final match = RegExp(r'@([a-zA-Z0-9_\.]*)$').firstMatch(before);
    if (match != null) {
      _mentionDebounce = Timer(
          const Duration(milliseconds: 200), () => _searchMentions(match.group(1) ?? ''));
    } else {
      if (mounted) {
        setState(() { _showMentionSuggestions = false; _mentionSuggestions = []; });
      }
    }
  }

  Future<void> _searchMentions(String query) async {
    try {
      final res = await dioClient.get('/v1/user/mention-search',
          queryParameters: {'q': query, 'limit': 4});
      if (res.data?['success'] == true && mounted) {
        final users = List<Map<String, dynamic>>.from(
            (res.data['users'] as List? ?? [])
                .map((u) => Map<String, dynamic>.from(u as Map)));
        setState(() {
          _mentionSuggestions = users;
          _showMentionSuggestions = users.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _showMentionSuggestions = false; _mentionSuggestions = []; });
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final text = _inputCtrl.text;
    final cursor = _cursorPos.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final match = RegExp(r'@([a-zA-Z0-9_\.]*)$').firstMatch(before);
    if (match != null) {
      final newText =
          '${before.substring(0, before.length - match[0]!.length)}@${user['username']} $after';
      _inputCtrl.text = newText;
      _inputCtrl.selection =
          TextSelection.collapsed(offset: newText.length - after.length);
    }
    setState(() { _showMentionSuggestions = false; _mentionSuggestions = []; });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _navigateToProfile(String userId) {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 300), () {
      // Navigation handled by go_router at app level
    });
  }

  Future<void> _onMentionPress(String username) async {
    try {
      final res = await dioClient.get('/v1/user/find/$username');
      final data = res.data['data'] ?? res.data;
      final id = data?['id']?.toString();
      if (id != null && mounted) _navigateToProfile(id);
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    final keyboardH = mq.viewInsets.bottom;
    final safeBottom = mq.padding.bottom;

    // Padding(bottom: keyboardH) places empty space where the keyboard is.
    // The container shrinks by keyboardH so its bottom sits exactly at the
    // keyboard top. This mirrors Android adjustResize behaviour.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: Container(
        height: mq.size.height * 0.9 - keyboardH,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Sticky header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.background,
              border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
            ),
            child: Row(children: [
              Text('Comments',
                  style: TextStyle(color: c.text, fontSize: 18,
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              if (_total > 0) ...[
                const SizedBox(width: 8),
                Text('$_total',
                    style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
              ],
            ]),
          ),
          // Comment list — fills all remaining space, footer sits below it naturally
          Expanded(child: _buildCommentList(c)),
          // Footer — always at the bottom of the column, never overlaid
          _buildFooter(c, safeBottom: safeBottom, keyboardH: keyboardH),
        ]),
      ),
    );
  }

  // Show delete dialog as a proper dialog overlay (no Stack needed)
  void _showDeleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CustomAlertDialog(
        visible: true,
        title: 'Delete Comment',
        message: 'Are you sure you want to delete this comment? This action cannot be undone.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
        type: 'danger',
        showCancel: true,
        onConfirm: () {
          Navigator.pop(context);
          _handleDeleteComment();
        },
        onCancel: () {
          Navigator.pop(context);
          setState(() { _commentToDelete = null; });
        },
      ),
    );
  }

  // ── Comment list ───────────────────────────────────────────────────────────

  Widget _buildCommentList(ThemeColors c) {
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: c.primary, strokeWidth: 2.5),
        const SizedBox(height: 12),
        Text('Loading comments...',
            style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
      ]));
    }

    final items = <_ListItem>[];
    for (final comment in _comments) {
      items.add(_ListItem.comment(comment));
      if (comment.replies.isNotEmpty) {
        if (_expandedReplies[comment.id] == true) {
          for (final reply in comment.replies) {
            items.add(_ListItem.reply(reply));
          }
        }
        items.add(_ListItem.viewReplies(
          comment.id, comment.replies.length, _expandedReplies[comment.id] == true));
      }
    }

    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('No comments yet',
            style: TextStyle(color: c.text, fontSize: 18,
                fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Be the first to comment',
            style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
      ]));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == items.length) return _buildLoadMore(c);
        final item = items[i];
        if (item.isViewReplies) return _buildViewRepliesButton(item, c);
        return _buildCommentItem(item.comment!, item.isReply, c);
      },
    );
  }

  Widget _buildLoadMore(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: _loadingMore
          ? Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2))
          : GestureDetector(
              onTap: () => _loadComments(loadMore: true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(child: Text(
                  'Load more comments (${_total - _comments.length} remaining)',
                  style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit'),
                )),
              ),
            ),
    );
  }

  Widget _buildViewRepliesButton(_ListItem item, ThemeColors c) {
    return GestureDetector(
      onTap: () => setState(() =>
          _expandedReplies[item.parentId!] = !(_expandedReplies[item.parentId!] ?? false)),
      child: Padding(
        padding: const EdgeInsets.only(left: 68, top: 4, bottom: 8, right: 16),
        child: Row(children: [
          Container(width: 24, height: 1, color: c.border, margin: const EdgeInsets.only(right: 8)),
          Text(
            item.isExpanded
                ? 'Hide replies'
                : 'View ${item.replyCount} ${item.replyCount == 1 ? 'reply' : 'replies'}',
            style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
          ),
        ]),
      ),
    );
  }

  Widget _buildCommentItem(_Comment comment, bool isReply, ThemeColors c) {
    final anim = _heartAnim(comment.id);
    return GestureDetector(
      onLongPress: () => _handleLongPress(comment),
      child: Container(
        padding: EdgeInsets.only(
          left: isReply ? 56 : 16,
          right: 16, top: 12, bottom: 12,
        ),
        decoration: isReply
            ? BoxDecoration(
                border: Border(left: BorderSide(color: c.border, width: 1)),
                color: Colors.transparent,
              )
            : null,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
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
                      (comment.username.isNotEmpty ? comment.username[0] : '?').toUpperCase(),
                      style: TextStyle(color: c.text, fontFamily: 'Outfit',
                          fontSize: 14, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Comment content
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(comment.userId),
                  child: Text(comment.username,
                      style: TextStyle(color: c.text, fontSize: 14,
                          fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                VerificationBadge(
                    isVerified: comment.isVerified,
                    badge: comment.verificationBadge,
                    size: 14),
                const SizedBox(width: 6),
                Text(comment.time,
                    style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit')),
              ]),
              const SizedBox(height: 4),
              _buildMentionText(comment.text, c),
              const SizedBox(height: 8),
              if (comment.userId != _uid)
                GestureDetector(
                  onTap: () => _handleReply(comment, isReply: isReply),
                  child: Text('Reply',
                      style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit')),
                ),
            ]),
          ),
          // Like button
          GestureDetector(
            onTap: () => _handleCommentLike(comment.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: anim,
                  builder: (context2, child) => Transform.scale(
                    scale: anim.value,
                    child: Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: comment.isLiked ? const Color(0xFFE74C3C) : c.textSecondary,
                    ),
                  ),
                ),
                if (comment.likes > 0) ...[
                  const SizedBox(height: 2),
                  Text('${comment.likes}',
                      style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit')),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMentionText(String text, ThemeColors c) {
    final pattern = RegExp(r'@([a-zA-Z0-9_]+)');
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final username = m.group(1)!;
      spans.add(TextSpan(
        text: '@$username',
        style: TextStyle(color: c.primary, fontFamily: 'Outfit',
            fontSize: 14, fontWeight: FontWeight.w600),
        recognizer: TapGestureRecognizer()..onTap = () => _onMentionPress(username),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(
      children: spans,
      style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit', height: 1.43),
    ));
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(ThemeColors c, {required double safeBottom, required double keyboardH}) {
    final bottomPad = keyboardH > 0 ? 12.0 : (safeBottom > 0 ? safeBottom : 12.0);

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottomPad),
      child: _postAuthorBlockedMe
          ? Row(children: [
              Icon(Icons.block, size: 18, color: c.textTertiary),
              const SizedBox(width: 8),
              Text('Commenting is not available on this post.',
                  style: TextStyle(color: c.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              // Reply indicator
              if (_replyingTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(
                      'Replying to ${_replyingTo!.username}',
                      style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
                    )),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Text('✕',
                          style: TextStyle(color: c.textTertiary, fontSize: 16,
                              fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              // Mention suggestions
              if (_showMentionSuggestions && _mentionSuggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: _mentionSuggestions.map((user) {
                      final pic = user['profile_pic'] as String?;
                      final name = (user['name'] as String?)?.isNotEmpty == true
                          ? user['name'] as String
                          : (user['username'] as String? ?? '?');
                      return GestureDetector(
                        onTap: () => _insertMention(user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: c.divider, width: 0.5))),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: c.primary.withValues(alpha: 0.2),
                              backgroundImage:
                                  pic != null ? CachedNetworkImageProvider(pic) : null,
                              child: pic == null
                                  ? Text(name[0].toUpperCase(),
                                      style: TextStyle(color: c.primary, fontSize: 14,
                                          fontFamily: 'Outfit', fontWeight: FontWeight.w600))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user['name'] ?? '',
                                  style: TextStyle(color: c.text, fontSize: 14,
                                      fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                              Text('@${user['username'] ?? ''}',
                                  style: TextStyle(color: c.textSecondary,
                                      fontSize: 12, fontFamily: 'Outfit')),
                            ]),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              // Emoji row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _emojis.map((emoji) => GestureDetector(
                    onTap: () {
                      final t = _inputCtrl.text + emoji;
                      _inputCtrl.text = t;
                      _inputCtrl.selection = TextSelection.collapsed(offset: t.length);
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 4),
              // Input row
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 12),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: c.border,
                    backgroundImage:
                        (_currentUserData?['profile_pic'] as String?) != null
                            ? CachedNetworkImageProvider(
                                _currentUserData!['profile_pic'] as String)
                            : null,
                    child: (_currentUserData?['profile_pic'] as String?) == null
                        ? Icon(Icons.person, color: c.textTertiary, size: 18)
                        : null,
                  ),
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 38, maxHeight: 120),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _inputFocus,
                      style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit'),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? 'Reply...' : 'Add a comment...',
                        hintStyle: TextStyle(color: c.textTertiary,
                            fontSize: 14, fontFamily: 'Outfit'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      maxLength: 2200,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onChanged: (t) {
                        _cursorPos = _inputCtrl.selection.extentOffset.clamp(0, t.length);
                        _onTextChanged(t);
                        setState(() {});
                      },
                      onTap: () {
                        _cursorPos = _inputCtrl.selection.extentOffset
                            .clamp(0, _inputCtrl.text.length);
                      },
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                ),
                if (_inputCtrl.text.trim().isNotEmpty || _posting) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _posting ? null : _postComment,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: _posting
                          ? Center(child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)))
                          : Icon(Icons.send, color: c.accent, size: 20),
                    ),
                  ),
                ],
              ]),
            ]),
    );
  }
}
