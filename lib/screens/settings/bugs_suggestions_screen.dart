import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get inputBg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get cardBg => dark ? const Color(0xFF1a1f2e) : const Color(0xFFF2F2F7);
}

// ─── Status helpers ───────────────────────────────────────────────────────────
Color _statusColor(String? s) {
  switch (s) {
    case 'pending': return const Color(0xFFFF9500);
    case 'in_progress':
    case 'under_review': return const Color(0xFF007AFF);
    case 'resolved':
    case 'accepted':
    case 'implemented': return const Color(0xFF34C759);
    case 'closed':
    case 'rejected': return const Color(0xFF8E8E93);
    default: return const Color(0xFF8E8E93);
  }
}

String _statusLabel(String? s) {
  switch (s) {
    case 'pending': return 'Pending';
    case 'in_progress': return 'In Progress';
    case 'under_review': return 'Under Review';
    case 'resolved': return 'Resolved';
    case 'accepted': return 'Accepted';
    case 'rejected': return 'Rejected';
    case 'implemented': return 'Implemented';
    case 'closed': return 'Closed';
    default: return s ?? '';
  }
}

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
  } catch (_) { return ''; }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class BugsSuggestionsScreen extends ConsumerStatefulWidget {
  const BugsSuggestionsScreen({super.key});
  @override
  ConsumerState<BugsSuggestionsScreen> createState() => _BugsSuggestionsScreenState();
}

class _BugsSuggestionsScreenState extends ConsumerState<BugsSuggestionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _bugs = [];
  bool _loading = true;
  bool _refreshing = false;
  final Set<String> _votingIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!_refreshing) setState(() => _loading = true);
    await Future.wait([_fetchSuggestions(), _fetchBugs()]);
    if (mounted) setState(() { _loading = false; _refreshing = false; });
  }

  Future<void> _fetchSuggestions() async {
    try {
      final res = await dioClient.get('/v1/feedback/suggestions/public', queryParameters: {'sort': 'votes', 'limit': 50});
      if (mounted && res.data['success'] == true) {
        final raw = res.data['statusCode']?['suggestions'] ?? res.data['data']?['suggestions'] ?? [];
        setState(() => _suggestions = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _fetchBugs() async {
    try {
      final res = await dioClient.get('/v1/feedback/bugs/public', queryParameters: {'limit': 50});
      if (mounted && res.data['success'] == true) {
        final raw = res.data['statusCode']?['reports'] ?? res.data['data']?['reports'] ?? [];
        setState(() => _bugs = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadAll();
  }

  Future<void> _vote(String id, String voteType) async {
    if (_votingIds.contains(id)) return;
    _votingIds.add(id);

    // Optimistic update
    setState(() {
      _suggestions = _suggestions.map((s) {
        if (s['id'].toString() != id) return s;
        final cur = s['user_vote'];
        int votes = (s['votes'] as num?)?.toInt() ?? 0;
        String? newVote = voteType;
        if (cur == voteType) { newVote = null; votes += voteType == 'upvote' ? -1 : 1; }
        else if (cur == null) { votes += voteType == 'upvote' ? 1 : -1; }
        else { votes += voteType == 'upvote' ? 2 : -2; }
        return {...s, 'votes': votes, 'user_vote': newVote};
      }).toList();
    });

    try {
      final res = await dioClient.post('/v1/feedback/suggestions/$id/toggle-vote', data: {'vote_type': voteType});
      if (mounted && res.data['success'] == true) {
        final d = res.data['statusCode'] ?? res.data['data'] ?? {};
        setState(() {
          _suggestions = _suggestions.map((s) => s['id'].toString() == id ? {...s, 'votes': d['votes'] ?? s['votes'], 'user_vote': d['user_vote']} : s).toList();
        });
      }
    } catch (_) { _fetchSuggestions(); }
    finally { _votingIds.remove(id); }
  }

  void _showReportBug(_T t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SubmitSheet(
        t: t,
        title: 'Report a Bug',
        icon: Icons.bug_report,
        iconColor: const Color(0xFFFF6B9D),
        descHint: 'Describe the bug you encountered (min 10 chars)…',
        onSubmit: (screenName, desc) async {
          await dioClient.post('/v1/feedback/bugs', data: {
            'description': desc,
            if (screenName.isNotEmpty) 'screen_name': screenName,
          });
        },
        onDone: _fetchBugs,
      ),
    );
  }

  void _showSuggestIdea(_T t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SubmitSheet(
        t: t,
        title: 'Suggest an Idea',
        icon: Icons.lightbulb,
        iconColor: const Color(0xFF4A90E2),
        descHint: 'Describe your suggestion (min 10 chars)…',
        onSubmit: (screenName, desc) async {
          await dioClient.post('/v1/feedback/suggestions', data: {
            'description': desc,
            if (screenName.isNotEmpty) 'screen_name': screenName,
          });
        },
        onDone: _fetchSuggestions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: Container(width: 40, height: 56, alignment: Alignment.center, child: Icon(Icons.arrow_back, size: 24, color: t.text))),
            Expanded(child: Text('Bugs & Suggestions', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
            const SizedBox(width: 40),
          ]),
        ),

        // Action cards
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _showReportBug(t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B9D), Color(0xFFC44569)]), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bug_report, size: 22, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Report Bug', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => _showSuggestIdea(t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF357ABD)]), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lightbulb, size: 22, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Suggest Idea', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                ]),
              ),
            )),
          ]),
        ),

        // Tabs
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: t.primary,
            indicatorWeight: 2,
            labelColor: t.primary,
            unselectedLabelColor: t.textSecondary,
            labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb, size: 18),
                const SizedBox(width: 6),
                const Text('Suggestions'),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _badge(_suggestions.length, t),
                ],
              ])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bug_report, size: 18),
                const SizedBox(width: 6),
                const Text('Bug Reports'),
                if (_bugs.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _badge(_bugs.length, t),
                ],
              ])),
            ],
          ),
        ),

        // Content
        Expanded(child: _loading
            ? Center(child: CircularProgressIndicator(color: t.primary))
            : TabBarView(controller: _tabCtrl, children: [
                _suggestionList(t),
                _bugList(t),
              ])),
      ])),
    );
  }

  Widget _badge(int count, _T t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: t.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
    child: Text('$count', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11, color: t.primary)),
  );

  Widget _suggestionList(_T t) => RefreshIndicator(
    onRefresh: _onRefresh,
    color: t.primary,
    backgroundColor: t.surface,
    child: _suggestions.isEmpty
        ? _emptyState(Icons.lightbulb, 'No suggestions yet', 'Be the first to share an idea!', t)
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: _suggestions.length,
            itemBuilder: (_, i) => _suggestionCard(_suggestions[i], t),
          ),
  );

  Widget _bugList(_T t) => RefreshIndicator(
    onRefresh: _onRefresh,
    color: t.primary,
    backgroundColor: t.surface,
    child: _bugs.isEmpty
        ? _emptyState(Icons.bug_report, 'No bug reports yet', 'No bugs reported yet. Great!', t)
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: _bugs.length,
            itemBuilder: (_, i) => _bugCard(_bugs[i], t),
          ),
  );

  Widget _suggestionCard(Map<String, dynamic> item, _T t) {
    final id = item['id'].toString();
    final isImplemented = item['status'] == 'implemented';
    final votes = (item['votes'] as num?)?.toInt() ?? 0;
    final userVote = item['user_vote']?.toString();
    final isVoting = _votingIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
      clipBehavior: Clip.hardEdge,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Vote column
        Opacity(opacity: isImplemented ? 0.4 : 1, child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            GestureDetector(
              onTap: (isVoting || isImplemented) ? null : () => _vote(id, 'upvote'),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: userVote == 'upvote' ? const Color(0x1534C759) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.keyboard_arrow_up, size: 28, color: userVote == 'upvote' ? const Color(0xFF34C759) : t.textSecondary),
              ),
            ),
            Text('$votes', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15, color: votes > 0 ? const Color(0xFF34C759) : votes < 0 ? const Color(0xFFFF453A) : t.text)),
            GestureDetector(
              onTap: (isVoting || isImplemented) ? null : () => _vote(id, 'downvote'),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: userVote == 'downvote' ? const Color(0x15FF453A) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.keyboard_arrow_down, size: 28, color: userVote == 'downvote' ? const Color(0xFFFF453A) : t.textSecondary),
              ),
            ),
          ]),
        )),
        // Content
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
          child: _cardContent(item, null, t),
        )),
      ]),
    );
  }

  Widget _bugCard(Map<String, dynamic> item, _T t) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
    clipBehavior: Clip.hardEdge,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 48, padding: const EdgeInsets.only(top: 16), child: const Icon(Icons.bug_report, size: 24, color: Color(0xFFFF6B9D))),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
        child: _cardContent(item, item['priority']?.toString(), t),
      )),
    ]),
  );

  Widget _cardContent(Map<String, dynamic> item, String? priority, _T t) {
    final status = item['status']?.toString();
    final color = _statusColor(status);
    final pic = item['profile_pic']?.toString();
    final username = item['user_name']?.toString() ?? item['username']?.toString() ?? 'Anonymous';
    final screenName = item['screen_name']?.toString();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Avatar
        ClipOval(child: pic != null && pic.isNotEmpty
            ? CachedNetworkImage(imageUrl: pic, width: 24, height: 24, fit: BoxFit.cover)
            : Container(width: 24, height: 24, color: t.cardBg, child: Icon(Icons.person, size: 16, color: t.textTertiary))),
        const SizedBox(width: 6),
        Expanded(child: Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13, color: t.textSecondary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(_statusLabel(status), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: color)),
        ),
      ]),
      const SizedBox(height: 6),
      Text(item['description']?.toString() ?? '', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.text, height: 1.4)),
      const SizedBox(height: 8),
      Row(children: [
        if (screenName != null && screenName.isNotEmpty) ...[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.smartphone, size: 12, color: t.textTertiary),
                const SizedBox(width: 3),
                Flexible(child: Text(screenName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary))),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (priority != null && priority != 'medium') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _priorityColor(priority).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(priority, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: _priorityColor(priority))),
          ),
          const SizedBox(width: 8),
        ],
        const Spacer(),
        Text(_timeAgo(item['created_at']?.toString()), style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
      ]),
    ]);
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical': return const Color(0xFFFF453A);
      case 'high': return const Color(0xFFFF9500);
      default: return const Color(0xFF8E8E93);
    }
  }

  Widget _emptyState(IconData icon, String title, String subtitle, _T t) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: t.textTertiary),
      const SizedBox(height: 16),
      Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary), textAlign: TextAlign.center),
    ]),
  ));
}

// ─── Submit bottom sheet ──────────────────────────────────────────────────────
class _SubmitSheet extends StatefulWidget {
  final _T t;
  final String title;
  final IconData icon;
  final Color iconColor;
  final String descHint;
  final Future<void> Function(String screenName, String description) onSubmit;
  final VoidCallback onDone;
  const _SubmitSheet({required this.t, required this.title, required this.icon, required this.iconColor, required this.descHint, required this.onSubmit, required this.onDone});
  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  final _screenCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _screenCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) { _snack('Please provide a description'); return; }
    if (desc.length < 10) { _snack('Please provide a more detailed description (at least 10 characters)'); return; }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_screenCtrl.text.trim(), desc);
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted! Thank you.', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Color(0xFF34C759)));
      }
    } catch (_) {
      if (mounted) { setState(() => _submitting = false); _snack('Failed to submit. Please try again.'); }
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: const Color(0xFFFF453A)));

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final btmPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, btmPad),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)))),
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: widget.iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(widget.icon, size: 20, color: widget.iconColor)),
          const SizedBox(width: 12),
          Text(widget.title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, color: t.text)),
        ]),
        const SizedBox(height: 16),
        Text('Screen / Feature (optional)', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary)),
        const SizedBox(height: 6),
        _field(_screenCtrl, 'e.g. Home Screen, Chat', maxLines: 1, t: t),
        const SizedBox(height: 12),
        Text('Description *', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary)),
        const SizedBox(height: 6),
        _field(_descCtrl, widget.descHint, maxLines: 5, maxLength: 5000, t: t),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _submitting ? null : _submit,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: widget.iconColor, borderRadius: BorderRadius.circular(14)),
            child: _submitting
                ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : const Center(child: Text('Submit', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white))),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {required int maxLines, int? maxLength, required _T t}) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    maxLength: maxLength,
    style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.text),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontFamily: 'Outfit', color: t.textTertiary),
      counterStyle: TextStyle(color: t.textTertiary),
      filled: true, fillColor: t.inputBg,
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.primary)),
    ),
  );
}
