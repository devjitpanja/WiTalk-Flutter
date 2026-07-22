import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get tabActiveBg => dark ? const Color(0xFF2b3036) : const Color(0xFFf4f5f7);
  Color get tabInactiveBorder => dark ? const Color(0xFF2b3036) : const Color(0xFFE0E0E0);
  Color get videoOverlay => const Color(0xB3000000);
  Color get textOnlyBg => dark ? const Color(0xFF2a2f3e) : const Color(0xFFE0E0E0);
  Color get textPreview => dark ? const Color(0xFF8E8E93) : const Color(0xFF666666);
}

const _tabs = [('all', 'All'), ('posts', 'Posts'), ('mini', 'Mini')];

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  String _tab = 'all';
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  int _page = 1;
  bool _hasMore = true;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(1);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && _hasMore && !_loadingMore) {
      _load(_page + 1, append: true);
    }
  }

  Future<void> _load(int page, {bool append = false}) async {
    if (!append) {
      if (!mounted) return;
      setState(() => _loading = true);
    } else {
      if (!mounted) return;
      setState(() => _loadingMore = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) return;
      final res = await dioClient.get('/v1/post-saves/$uid', queryParameters: {'page': page, 'limit': 20});
      if (!mounted) return;
      final raw = res.data['data'];
      List<dynamic> rawPosts = [];
      Map<String, dynamic>? pagination;
      if (raw is List) {
        rawPosts = raw;
      } else if (raw is Map) {
        rawPosts = (raw['posts'] as List?) ?? [];
        pagination = raw['pagination'] as Map<String, dynamic>?;
      }
      var posts = rawPosts.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Client-side tab filter
      if (_tab == 'posts') {
        posts = posts.where((p) {
          final m = _parseMedia(p['media']);
          if (m.isEmpty) return true;
          return !m.any((item) => item['type'] == 'video');
        }).toList();
      } else if (_tab == 'mini') {
        posts = posts.where((p) {
          final m = _parseMedia(p['media']);
          return m.any((item) => item['type'] == 'video');
        }).toList();
      }

      setState(() {
        _posts = append ? [..._posts, ...posts] : posts;
        _page = (pagination?['currentPage'] as num?)?.toInt() ?? page;
        _hasMore = pagination?['hasNextPage'] == true;
      });
    } catch (_) {}
    finally { if (mounted) setState(() { _loading = false; _loadingMore = false; _refreshing = false; }); }
  }

  List<Map<String, dynamic>> _parseMedia(dynamic raw) {
    if (raw == null) return [];
    try {
      if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (raw is String) {
        // Basic JSON-like parse for common case
        return [];
      }
    } catch (_) {}
    return [];
  }

  void _setTab(String tab) {
    if (tab == _tab) return;
    setState(() { _tab = tab; _posts = []; _page = 1; _hasMore = true; });
    _load(1);
  }

  Future<void> _onRefresh() async {
    setState(() { _refreshing = true; _page = 1; _hasMore = true; });
    await _load(1);
  }

  void _openPost(Map<String, dynamic> post) {
    final suffix = post['suffix']?.toString();
    if (suffix != null && suffix.isNotEmpty) {
      context.push('/post-view/$suffix');
    } else {
      final id = post['post_id']?.toString() ?? post['id']?.toString();
      if (id != null) context.push('/post/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final screenW = MediaQuery.of(context).size.width;
    final itemW = (screenW - 24) / 3;
    final itemH = (screenW - 24) / 2;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            GestureDetector(onTap: () => context.pop(), child: const Padding(padding: EdgeInsets.fromLTRB(0, 8, 8, 8), child: Icon(Icons.arrow_back, size: 24))),
            const SizedBox(width: 4),
            Text('Saved', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text)),
          ]),
        ),

        // Tabs
        Container(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Row(children: _tabs.map((tab) {
            final active = _tab == tab.$1;
            return GestureDetector(
              onTap: () => _setTab(tab.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? t.tabActiveBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: active ? t.tabActiveBg : t.tabInactiveBorder),
                ),
                child: Text(tab.$2, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 12, color: t.text)),
              ),
            );
          }).toList()),
        ),

        // Grid
        Expanded(child: _loading && _posts.isEmpty
            ? Center(child: CircularProgressIndicator(color: t.primary))
            : CustomScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                  if (_posts.isEmpty)
                    SliverFillRemaining(child: _emptyState(t))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: itemW / itemH,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i == _posts.length) return Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)));
                            return _postTile(_posts[i], t);
                          },
                          childCount: _posts.length + (_loadingMore ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              )),
      ])),
    );
  }

  Widget _postTile(Map<String, dynamic> post, _T t) {
    final media = _parseMedia(post['media']);
    final first = media.isNotEmpty ? media[0] : null;
    final isVideo = first?['type'] == 'video';
    final hasMulti = media.length > 1;

    Widget content;
    if (isVideo) {
      final thumb = first?['thumbnail']?.toString();
      content = thumb != null && thumb.isNotEmpty
          ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
          : Container(color: Colors.black, child: const Center(child: Icon(Icons.play_circle_outline, size: 40, color: Colors.white)));
    } else if (first != null && first['type'] == 'image') {
      final url = first['url']?.toString() ?? '';
      content = CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      content = Container(
        color: t.textOnlyBg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Text(post['content']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textPreview)),
      );
    }

    return GestureDetector(
      onTap: () => _openPost(post),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(fit: StackFit.expand, children: [
          content,
          if (isVideo) Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: t.videoOverlay, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.play_arrow, size: 20, color: Colors.white))),
          if (hasMulti) Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: t.videoOverlay, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.collections, size: 16, color: Colors.white))),
        ]),
      ),
    );
  }

  Widget _emptyState(_T t) => ListView(children: [
    const SizedBox(height: 80),
    Column(children: [
      Icon(Icons.bookmark_border, size: 80, color: t.textTertiary),
      const SizedBox(height: 20),
      Text('No saved posts', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 20, color: t.text)),
      const SizedBox(height: 8),
      Text(
        _tab == 'all' ? 'Posts you save will appear here' : _tab == 'posts' ? 'Saved posts with media will appear here' : 'Saved video posts will appear here',
        style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary),
        textAlign: TextAlign.center,
      ),
    ]),
  ]);
}
