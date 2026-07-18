import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/post_card.dart';

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

  // Local mutable copy of posts (so like/comment updates don't require a full refetch)
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.bookmark_border, color: Colors.white),
          title: const Text('Save post', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); },
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.white),
          title: const Text('Report', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); context.push('/report/post/$postId'); },
        ),
        ListTile(
          leading: const Icon(Icons.block, color: Colors.white),
          title: const Text('Block user', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
          onTap: () { Navigator.pop(context); },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(_feedProvider);
    final currentUserId = ref.watch(authProvider).uid;

    // Seed local posts once when the provider loads
    feedAsync.whenData((posts) {
      if (_posts == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _posts = List.from(posts));
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          AnimatedSlide(
            offset: _headerVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 200),
            child: _buildHeader(),
          ),
          Expanded(
            child: feedAsync.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => _buildError(e),
              data: (_) {
                final posts = _posts;
                if (posts == null) return _buildSkeleton();
                return RefreshIndicator(
                  color: AppColors.primaryButton,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    setState(() => _posts = null);
                    await ref.refresh(_feedProvider.future);  // ignore: unused_result
                  },
                  child: posts.isEmpty
                      ? _buildEmpty()
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

  Widget _buildHeader() => Container(
    height: 56,
    color: AppColors.background,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      const Text(
        'WiTalk',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit', letterSpacing: 0.5),
      ),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: () => context.push('/search'),
      ),
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () => context.push('/notifications'),
      ),
    ]),
  );

  Widget _buildSkeleton() => ListView.builder(
    itemCount: 4,
    itemBuilder: (context2, idx) => Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.border,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        height: 300,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  Widget _buildError(Object e) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off, color: AppColors.textTertiary, size: 48),
      const SizedBox(height: 12),
      const Text('Could not load feed', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit')),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () {
          setState(() => _posts = null);
          ref.refresh(_feedProvider.future);  // ignore: unused_result
        },
        child: const Text('Retry', style: TextStyle(color: AppColors.primaryButton, fontFamily: 'Outfit')),
      ),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('👋', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('Your feed is empty', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Follow people to see their posts here', style: TextStyle(color: AppColors.textTertiary, fontSize: 14, fontFamily: 'Outfit')),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => context.push('/discover-people'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Discover People', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}
