import 'package:flutter/cupertino.dart';
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
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  } catch (_) {
    return '';
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

const _tabs = ['All', 'Open', 'Closed', 'Pinned'];
const _tabStatuses = [null, 'open', 'closed', null]; // null = no status filter

// ── Widget ────────────────────────────────────────────────────────────────────

class TopicsListView extends ConsumerStatefulWidget {
  final String groupId;
  final bool isAdmin;

  const TopicsListView({
    super.key,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  ConsumerState<TopicsListView> createState() => _TopicsListViewState();
}

class _TopicsListViewState extends ConsumerState<TopicsListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final List<List<Map<String, dynamic>>> _topicsByTab =
      List.generate(4, (_) => []);
  final List<bool> _loadingByTab = List.generate(4, (_) => false);
  final List<bool> _hasMoreByTab = List.generate(4, (_) => true);
  final List<int> _pageByTab = List.generate(4, (_) => 1);

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _ensureLoaded(_tabCtrl.index);
      }
    });
    _loadTab(0);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _ensureLoaded(int idx) {
    if (_topicsByTab[idx].isEmpty && !_loadingByTab[idx]) {
      _loadTab(idx);
    }
  }

  Future<void> _loadTab(int idx, {bool reset = false}) async {
    if (_loadingByTab[idx] && !reset) return;
    if (reset) {
      _pageByTab[idx] = 1;
      _hasMoreByTab[idx] = true;
      _topicsByTab[idx] = [];
    }
    setState(() => _loadingByTab[idx] = true);
    try {
      final isPinned = idx == 3;
      List<Map<String, dynamic>> items;
      if (isPinned) {
        final res = await dioClient.get(
          AppEndpoints.groupTopics(widget.groupId),
          queryParameters: {
            'pinned': true,
            'page': _pageByTab[idx],
            'limit': _pageSize,
          },
        );
        final data = res.data['data'];
        if (data is List) {
          items = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['topics'] is List) {
          items = List<Map<String, dynamic>>.from(data['topics'] as List);
        } else {
          items = [];
        }
      } else {
        items = await chatApiService.getGroupTopics(
          widget.groupId,
          status: _tabStatuses[idx],
          page: _pageByTab[idx],
          limit: _pageSize,
        );
      }
      if (mounted) {
        setState(() {
          if (reset || _pageByTab[idx] == 1) {
            _topicsByTab[idx] = items;
          } else {
            _topicsByTab[idx] = [..._topicsByTab[idx], ...items];
          }
          _hasMoreByTab[idx] = items.length >= _pageSize;
          _pageByTab[idx]++;
          _loadingByTab[idx] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingByTab[idx] = false);
    }
  }

  Future<void> _refresh(int idx) => _loadTab(idx, reset: true);

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTopicSheet(
        groupId: widget.groupId,
        onCreated: () {
          for (int i = 0; i < 4; i++) {
            _loadTab(i, reset: true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        // Tab bar
        Container(
          color: c.background,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: c.primary,
            unselectedLabelColor: c.textTertiary,
            indicatorColor: c.primary,

            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: List.generate(
              _tabs.length,
              (idx) => _TopicTabPage(
                topics: _topicsByTab[idx],
                loading: _loadingByTab[idx],
                hasMore: _hasMoreByTab[idx],
                groupId: widget.groupId,
                isAdmin: widget.isAdmin,
                tabIndex: idx,
                onRefresh: () => _refresh(idx),
                onLoadMore: () => _loadTab(idx),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab page ──────────────────────────────────────────────────────────────────

class _TopicTabPage extends StatelessWidget {
  final List<Map<String, dynamic>> topics;
  final bool loading;
  final bool hasMore;
  final String groupId;
  final bool isAdmin;
  final int tabIndex;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;

  const _TopicTabPage({
    required this.topics,
    required this.loading,
    required this.hasMore,
    required this.groupId,
    required this.isAdmin,
    required this.tabIndex,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (loading && topics.isEmpty) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    if (!loading && topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.topic_outlined, size: 56, color: c.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No topics yet',
              style: TextStyle(
                color: c.text,
                fontSize: 17,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a discussion with the group',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: () async => onRefresh()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                if (i == topics.length) {
                  // Load more trigger
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => onLoadMore());
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.primary),
                      ),
                    ),
                  );
                }
                return _TopicCard(
                  topic: topics[i],
                  groupId: groupId,
                  isAdmin: isAdmin,
                );
              },
              childCount: topics.length + (hasMore ? 1 : 0),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Topic card ────────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final Map<String, dynamic> topic;
  final String groupId;
  final bool isAdmin;

  const _TopicCard({
    required this.topic,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final author = topic['author'] as Map<String, dynamic>? ??
        topic['created_by'] as Map<String, dynamic>? ??
        {};
    final authorName =
        author['name']?.toString() ?? author['username']?.toString() ?? '';
    final authorPic = author['profile_pic']?.toString();
    final title = topic['title']?.toString() ?? '';
    final type = topic['type']?.toString() ?? 'discussion';
    final status = topic['status']?.toString() ?? 'open';
    final isPinned = topic['is_pinned'] == true;
    final replyCount = (topic['reply_count'] as num?)?.toInt() ?? 0;
    final voteCount = (topic['vote_count'] as num?)?.toInt() ??
        (topic['votes'] as num?)?.toInt() ??
        0;
    final createdAt = topic['created_at']?.toString();
    final topicId = topic['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () =>
          context.push('/chat/group-topic/$groupId/$topicId'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pin + type + status row
            Row(
              children: [
                if (isPinned) ...[
                  Icon(Icons.push_pin, size: 14, color: c.warning),
                  const SizedBox(width: 4),
                ],
                _TypeBadge(type: type, c: c),
                const SizedBox(width: 8),
                _StatusBadge(status: status, c: c),
                const Spacer(),
                Text(
                  _timeAgo(createdAt),
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 11,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            // Author + counters
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: c.border,
                  backgroundImage: authorPic != null
                      ? CachedNetworkImageProvider(authorPic)
                      : null,
                  child: authorPic == null
                      ? Text(
                          authorName.isNotEmpty
                              ? authorName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: c.text,
                              fontSize: 10,
                              fontFamily: 'Outfit'),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                _Counter(
                  icon: Icons.chat_bubble_outline,
                  count: replyCount,
                  c: c,
                ),
                const SizedBox(width: 12),
                _Counter(
                  icon: Icons.thumb_up_outlined,
                  count: voteCount,
                  c: c,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small composites ──────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  final ThemeColors c;
  const _TypeBadge({required this.type, required this.c});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    switch (type) {
      case 'poll':
        bg = c.primary.withOpacity(0.15);
        label = 'Poll';
        break;
      case 'announcement':
        bg = c.warning.withOpacity(0.15);
        label = 'Announcement';
        break;
      default:
        bg = c.success.withOpacity(0.15);
        label = 'Discussion';
    }
    final textColor =
        type == 'poll' ? c.primary : (type == 'announcement' ? c.warning : c.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
          fontSize: 10,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final int count;
  final ThemeColors c;
  const _Counter({required this.icon, required this.count, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.textTertiary),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            color: c.textTertiary,
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}

// ── CreateTopicSheet (forward declaration — actual impl in separate file) ──────
// This import keeps topics_list_view self-contained and allows showing the sheet.

class CreateTopicSheet extends StatefulWidget {
  final String groupId;
  final VoidCallback onCreated;
  const CreateTopicSheet(
      {super.key, required this.groupId, required this.onCreated});

  @override
  State<CreateTopicSheet> createState() => _CreateTopicSheetState();
}

class _CreateTopicSheetState extends State<CreateTopicSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _type = 'discussion';
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _submitting = true);
    try {
      List<String>? options;
      if (_type == 'poll') {
        options = _pollOptions
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (options.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Add at least 2 poll options')));
          }
          setState(() => _submitting = false);
          return;
        }
      }
      await chatApiService.createGroupTopic(
        groupId: widget.groupId,
        title: title,
        content: content,
        type: _type,
        options: options,
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create topic')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'New Topic',
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            // Type selector
            Row(
              children: ['discussion', 'poll', 'announcement'].map((t) {
                final selected = _type == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? c.primary : c.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected ? c.primary : c.border),
                      ),
                      child: Text(
                        t[0].toUpperCase() + t.substring(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : c.textSecondary,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Title
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle:
                    TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.primary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Content
            TextField(
              controller: _contentCtrl,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(color: c.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle:
                    TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.primary),
                ),
              ),
            ),
            // Poll options
            if (_type == 'poll') ...[
              const SizedBox(height: 12),
              Text(
                'Poll Options',
                style: TextStyle(
                  color: c.textSecondary,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_pollOptions.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pollOptions[i],
                          style:
                              TextStyle(color: c.text, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            hintStyle: TextStyle(
                                color: c.placeholder, fontFamily: 'Outfit'),
                            filled: true,
                            fillColor: c.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: c.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: c.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: c.primary),
                            ),
                          ),
                        ),
                      ),
                      if (_pollOptions.length > 2)
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: c.error),
                          onPressed: () => setState(() {
                            _pollOptions[i].dispose();
                            _pollOptions.removeAt(i);
                          }),
                        ),
                    ],
                  ),
                );
              }),
              if (_pollOptions.length < 6)
                TextButton.icon(
                  onPressed: () => setState(() =>
                      _pollOptions.add(TextEditingController())),
                  icon: Icon(Icons.add, color: c.primary, size: 18),
                  label: Text('Add Option',
                      style: TextStyle(
                          color: c.primary,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600)),
                ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primaryButton,
                disabledBackgroundColor: c.primaryButtonDisabled,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Create Topic',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
