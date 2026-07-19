import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/post_card.dart';
import '../../widgets/common/witalk_header.dart';

const _homeFeedQuery = r'''
  query GetHomeFeed($userId: ID!, $page: Int!, $limit: Int!) {
    homeFeed(
      userId: $userId
      pagination: { page: $page, limit: $limit }
      filter: {}
    ) {
      posts {
        id
        user_id
        content
        media { type url width height thumbnail duration aspectRatio }
        media_type
        stats { likes comments shares views }
        interactions { isLiked isFollowing isSaved }
        user { id name username profile_pic is_verified verification_badge { id name icon_url color } }
        suffix
        created_on
        updated_on
        status
      }
      pageInfo { currentPage totalPages hasNextPage totalCount }
    }
  }
''';

final _feedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(authProvider).uid ?? '';
  if (uid.isEmpty) return [];
  final res = await dioClient.post(
    '/graphql',
    data: {
      'query': _homeFeedQuery,
      'variables': {'userId': uid, 'page': 1, 'limit': 20},
    },
  );
  if (res.data['errors'] != null) throw Exception(res.data['errors'].toString());
  final posts = (res.data['data']['homeFeed']['posts'] ?? []) as List;
  return posts.map<Map<String, dynamic>>((p) {
    final stats = (p['stats'] as Map<String, dynamic>?) ?? {};
    final interactions = (p['interactions'] as Map<String, dynamic>?) ?? {};
    return {
      ...Map<String, dynamic>.from(p as Map),
      'likes': stats['likes'] ?? 0,
      'comments': stats['comments'] ?? 0,
      'shares': stats['shares'] ?? 0,
      'views': stats['views'] ?? 0,
      'isLiked': interactions['isLiked'] == true,
      'isSaved': interactions['isSaved'] == true,
      'isFollowing': interactions['isFollowing'] == true,
    };
  }).toList();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollCtrl = ScrollController();
  bool _headerVisible = true;
  double _lastScrollY = 0;

  List<Map<String, dynamic>>? _posts;

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
    final y = _scrollCtrl.offset;
    final diff = y - _lastScrollY;
    _lastScrollY = y;
    if (diff > 5 && _headerVisible) setState(() => _headerVisible = false);
    if (diff < -5 && !_headerVisible) setState(() => _headerVisible = true);
  }

  void _onLikeUpdate(String postId, bool isLiked, int count) {
    if (_posts == null) return;
    final idx = _posts!.indexWhere((p) => p['id'].toString() == postId);
    if (idx == -1) return;
    setState(() {
      _posts![idx] = {..._posts![idx], 'isLiked': isLiked, 'likes': count};
    });
  }

  void _onCommentUpdate(String postId, int count) {
    if (_posts == null) return;
    final idx = _posts!.indexWhere((p) => p['id'].toString() == postId);
    if (idx == -1) return;
    setState(() {
      _posts![idx] = {..._posts![idx], 'comments': count};
    });
  }

  void _onShowMoreMenu(String postId, String userId, Map<String, dynamic> extra) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.bookmark_border, color: c.text),
          title: Text('Save post', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); },
        ),
        ListTile(
          leading: Icon(Icons.flag_outlined, color: c.text),
          title: Text('Report', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); context.push('/report/post/$postId'); },
        ),
        ListTile(
          leading: Icon(Icons.block, color: c.text),
          title: Text('Block user', style: TextStyle(color: c.text, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feedAsync = ref.watch(_feedProvider);
    final currentUserId = ref.watch(authProvider).uid;

    feedAsync.whenData((posts) {
      if (_posts == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _posts = List.from(posts));
        });
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          AnimatedSlide(
            offset: _headerVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 200),
            child: _buildHeader(),
          ),
          Expanded(
            child: feedAsync.when(
              loading: () => _buildSkeleton(c),
              error: (e, _) => _buildError(e, c),
              data: (_) {
                final posts = _posts;
                if (posts == null) return _buildSkeleton(c);
                return RefreshIndicator(
                  color: c.primaryButton,
                  backgroundColor: c.surface,
                  onRefresh: () async {
                    setState(() => _posts = null);
                    await ref.refresh(_feedProvider.future);  // ignore: unused_result
                  },
                  child: posts.isEmpty
                      ? _buildEmpty(c)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: posts.length,
                          itemBuilder: (_, i) => PostCard(
                            post: posts[i],
                            currentUserId: currentUserId,
                            onLikeUpdate: _onLikeUpdate,
                            onCommentUpdate: _onCommentUpdate,
                            onShowMoreMenu: _onShowMoreMenu,
                          ),
                        ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => const WiTalkHeader(
    title: 'WiTalk',
    showBorder: true,
    showNotifications: true,
  );

  Widget _buildSkeleton(ThemeColors c) => ListView.builder(
    itemCount: 4,
    itemBuilder: (context2, idx) => Shimmer.fromColors(
      baseColor: c.surface,
      highlightColor: c.border,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        height: 300,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  Widget _buildError(Object e, ThemeColors c) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off, color: c.textTertiary, size: 48),
      const SizedBox(height: 12),
      Text('Could not load feed', style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit')),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () {
          setState(() => _posts = null);
          ref.refresh(_feedProvider.future);  // ignore: unused_result
        },
        child: Text('Retry', style: TextStyle(color: c.primaryButton, fontFamily: 'Outfit')),
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
