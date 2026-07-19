import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/theme_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../api/dio_client.dart';
import '../../../api/app_endpoints.dart';
import '../../../services/chat_api_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _timeAgo(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final d = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  } catch (_) {
    return '';
  }
}

String _formatDate(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final d = DateTime.parse(dateStr).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  } catch (_) {
    return '';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TopicDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String topicId;
  final bool isAdmin;

  const TopicDetailScreen({
    super.key,
    required this.groupId,
    required this.topicId,
    this.isAdmin = false,
  });

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
  Map<String, dynamic>? _topic;
  List<Map<String, dynamic>> _replies = [];
  bool _loadingTopic = true;
  bool _loadingReplies = false;
  bool _hasMore = true;
  int _page = 1;
  static const _pageSize = 20;

  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _submitting = false;
  String? _myVotedOptionId;
  bool _voting = false;
  bool _togglingStatus = false;
  bool _togglingPin = false;

  String? _currentUserId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.isAdmin;
    _currentUserId = ref.read(authProvider).uid;
    _scrollCtrl.addListener(_onScroll);
    _loadTopic();
    _loadReplies(reset: true);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loadingReplies) {
      _loadReplies();
    }
  }

  Future<void> _loadTopic() async {
    try {
      final data = await chatApiService.getGroupTopic(
          widget.groupId, widget.topicId);
      if (data != null && mounted) {
        // Check if current user already voted
        final options = data['options'] as List? ?? [];
        String? voted;
        for (final opt in options) {
          final o = opt as Map<String, dynamic>;
          final voters = o['voters'] as List? ?? [];
          if (voters.any((v) => v?.toString() == _currentUserId)) {
            voted = o['id']?.toString();
            break;
          }
        }
        setState(() {
          _topic = data;
          _myVotedOptionId = voted;
          _loadingTopic = false;
        });
      } else {
        if (mounted) setState(() => _loadingTopic = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTopic = false);
    }
  }

  Future<void> _loadReplies({bool reset = false}) async {
    if (_loadingReplies && !reset) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _replies = [];
    }
    setState(() => _loadingReplies = true);
    try {
      final items = await chatApiService.getTopicReplies(
        widget.groupId,
        widget.topicId,
        page: _page,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _replies = reset ? items : [..._replies, ...items];
          _hasMore = items.length >= _pageSize;
          _page++;
          _loadingReplies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  Future<void> _submitReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final reply = await chatApiService.createTopicReply(
        groupId: widget.groupId,
        topicId: widget.topicId,
        content: text,
      );
      _replyCtrl.clear();
      if (reply != null && mounted) {
        setState(() {
          _replies = [reply, ..._replies];
          // Bump reply count
          if (_topic != null) {
            final count =
                (_topic!['reply_count'] as num?)?.toInt() ?? 0;
            _topic!['reply_count'] = count + 1;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send reply')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _vote(String optionId) async {
    if (_voting || _myVotedOptionId != null) return;
    setState(() => _voting = true);
    try {
      await chatApiService.voteOnTopic(
          widget.groupId, widget.topicId, optionId);
      // Refresh topic to get updated counts
      final data = await chatApiService.getGroupTopic(
          widget.groupId, widget.topicId);
      if (data != null && mounted) {
        setState(() {
          _topic = data;
          _myVotedOptionId = optionId;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to vote')));
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _toggleStatus() async {
    final current = _topic?['status']?.toString() ?? 'open';
    final next = current == 'open' ? 'closed' : 'open';
    setState(() => _togglingStatus = true);
    try {
      await chatApiService.updateGroupTopicStatus(
          widget.groupId, widget.topicId, next);
      if (mounted) setState(() => _topic?['status'] = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to update status')));
      }
    } finally {
      if (mounted) setState(() => _togglingStatus = false);
    }
  }

  Future<void> _togglePin() async {
    final isPinned = _topic?['is_pinned'] == true;
    setState(() => _togglingPin = true);
    try {
      await chatApiService.pinGroupTopic(
          widget.groupId, widget.topicId, !isPinned);
      if (mounted) setState(() => _topic?['is_pinned'] = !isPinned);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to update pin')));
      }
    } finally {
      if (mounted) setState(() => _togglingPin = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Topic',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_isAdmin && _topic != null) ...[
            if (_togglingStatus || _togglingPin)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: c.text),
                color: c.surface,
                onSelected: (val) {
                  if (val == 'status') _toggleStatus();
                  if (val == 'pin') _togglePin();
                },
                itemBuilder: (_) {
                  final status =
                      _topic?['status']?.toString() ?? 'open';
                  final isPinned = _topic?['is_pinned'] == true;
                  return [
                    PopupMenuItem(
                      value: 'status',
                      child: Text(
                        status == 'open' ? 'Close Topic' : 'Reopen Topic',
                        style: TextStyle(
                            color: c.text, fontFamily: 'Outfit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(
                        isPinned ? 'Unpin Topic' : 'Pin Topic',
                        style: TextStyle(
                            color: c.text, fontFamily: 'Outfit'),
                      ),
                    ),
                  ];
                },
              ),
          ],
        ],
      ),
      body: _loadingTopic
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _topic == null
              ? Center(
                  child: Text('Topic not found',
                      style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit')))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        children: [
                          _buildHeader(c),
                          if (_topic!['type'] == 'poll') ...[
                            const SizedBox(height: 16),
                            _buildPollSection(c),
                          ],
                          const SizedBox(height: 20),
                          _buildRepliesSection(c),
                        ],
                      ),
                    ),
                    _buildReplyBar(c),
                  ],
                ),
    );
  }

  Widget _buildHeader(ThemeColors c) {
    final author = _topic!['author'] as Map<String, dynamic>? ??
        _topic!['created_by'] as Map<String, dynamic>? ??
        {};
    final authorName =
        author['name']?.toString() ?? author['username']?.toString() ?? '';
    final authorPic = author['profile_pic']?.toString();
    final title = _topic!['title']?.toString() ?? '';
    final content = _topic!['content']?.toString() ?? '';
    final type = _topic!['type']?.toString() ?? 'discussion';
    final status = _topic!['status']?.toString() ?? 'open';
    final isPinned = _topic!['is_pinned'] == true;
    final createdAt = _topic!['created_at']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badges row
        Row(
          children: [
            _TypeBadge(type: type, c: c),
            const SizedBox(width: 8),
            _StatusBadge(status: status, c: c),
            if (isPinned) ...[
              const SizedBox(width: 8),
              Icon(Icons.push_pin, size: 14, color: c.warning),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Title
        Text(
          title,
          style: TextStyle(
            color: c.text,
            fontSize: 20,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
          ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
              fontFamily: 'Outfit',
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Author + date
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: c.border,
              backgroundImage: authorPic != null
                  ? CachedNetworkImageProvider(authorPic)
                  : null,
              child: authorPic == null
                  ? Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: c.text,
                          fontSize: 11,
                          fontFamily: 'Outfit'),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              authorName,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: c.border, height: 1),
      ],
    );
  }

  Widget _buildPollSection(ThemeColors c) {
    final options = (_topic!['options'] as List? ?? [])
        .map((o) => o as Map<String, dynamic>)
        .toList();
    final totalVotes = options.fold<int>(
        0, (sum, o) => sum + ((o['vote_count'] as num?)?.toInt() ?? 0));
    final isClosed = _topic!['status'] == 'closed';
    final hasVoted = _myVotedOptionId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vote',
          style: TextStyle(
            color: c.text,
            fontSize: 16,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...options.map((opt) {
          final optId = opt['id']?.toString() ?? '';
          final optText = opt['text']?.toString() ?? opt['label']?.toString() ?? '';
          final votes = (opt['vote_count'] as num?)?.toInt() ?? 0;
          final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
          final isMyVote = _myVotedOptionId == optId;
          final canTap = !hasVoted && !isClosed && !_voting;

          return GestureDetector(
            onTap: canTap ? () => _vote(optId) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isMyVote
                    ? c.primary.withOpacity(0.15)
                    : c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isMyVote ? c.primary : c.border, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Progress bar
                  if (hasVoted || isClosed)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct,
                        child: Container(
                          color: isMyVote
                              ? c.primary.withOpacity(0.2)
                              : c.border.withOpacity(0.4),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            optText,
                            style: TextStyle(
                              color: isMyVote ? c.primary : c.text,
                              fontFamily: 'Outfit',
                              fontWeight: isMyVote
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (hasVoted || isClosed)
                          Text(
                            '${(pct * 100).round()}%',
                            style: TextStyle(
                              color: isMyVote ? c.primary : c.textSecondary,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Text(
          '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
          style: TextStyle(
            color: c.textTertiary,
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
        Divider(color: c.border, height: 24),
      ],
    );
  }

  Widget _buildRepliesSection(ThemeColors c) {
    final count =
        (_topic!['reply_count'] as num?)?.toInt() ?? _replies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ${count == 1 ? 'Reply' : 'Replies'}',
          style: TextStyle(
            color: c.text,
            fontSize: 15,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (_replies.isEmpty && _loadingReplies)
          Center(
              child: CircularProgressIndicator(color: c.primary))
        else if (_replies.isEmpty && !_loadingReplies)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No replies yet. Be the first!',
                style: TextStyle(
                    color: c.textTertiary, fontFamily: 'Outfit'),
              ),
            ),
          )
        else
          ...List.generate(_replies.length, (i) {
            final r = _replies[i];
            return _ReplyCard(reply: r, c: c);
          }),
        if (_hasMore && _replies.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _loadingReplies
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.primary))
                  : TextButton(
                      onPressed: () => _loadReplies(),
                      child: Text('Load more',
                          style: TextStyle(
                              color: c.primary, fontFamily: 'Outfit')),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyBar(ThemeColors c) {
    final isClosed = _topic?['status'] == 'closed';
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              enabled: !isClosed,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText:
                    isClosed ? 'Topic is closed' : 'Write a reply...',
                hintStyle:
                    TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (_submitting || isClosed) ? null : _submitReply,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isClosed ? c.border : c.primaryButton,
                shape: BoxShape.circle,
              ),
              child: _submitting
                  ? const Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reply card ────────────────────────────────────────────────────────────────

class _ReplyCard extends StatelessWidget {
  final Map<String, dynamic> reply;
  final ThemeColors c;
  const _ReplyCard({required this.reply, required this.c});

  @override
  Widget build(BuildContext context) {
    final author = reply['author'] as Map<String, dynamic>? ??
        reply['user'] as Map<String, dynamic>? ??
        {};
    final name =
        author['name']?.toString() ?? author['username']?.toString() ?? '';
    final pic = author['profile_pic']?.toString();
    final content = reply['content']?.toString() ?? '';
    final createdAt = reply['created_at']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: c.border,
            backgroundImage:
                pic != null ? CachedNetworkImageProvider(pic) : null,
            child: pic == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: c.text, fontSize: 11, fontFamily: 'Outfit'),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: c.text,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(createdAt),
                      style: TextStyle(
                        color: c.textTertiary,
                        fontFamily: 'Outfit',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  final ThemeColors c;
  const _TypeBadge({required this.type, required this.c});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (type) {
      case 'poll':
        bg = c.primary.withOpacity(0.15);
        fg = c.primary;
        label = 'Poll';
        break;
      case 'announcement':
        bg = c.warning.withOpacity(0.15);
        fg = c.warning;
        label = 'Announcement';
        break;
      default:
        bg = c.success.withOpacity(0.15);
        fg = c.success;
        label = 'Discussion';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 11,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final ThemeColors c;
  const _StatusBadge({required this.status, required this.c});

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'closed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isClosed
            ? c.textTertiary.withOpacity(0.15)
            : c.success.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isClosed ? 'Closed' : 'Open',
        style: TextStyle(
          color: isClosed ? c.textTertiary : c.success,
          fontSize: 11,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
