import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/graphql_service.dart';
import 'auth_provider.dart';

const homeFeedQuery = r'''
  query GetHomeFeed(
    $userId: ID!
    $page: Int!
    $limit: Int!
    $mediaType: MediaType
    $forceRefresh: Boolean
  ) {
    homeFeed(
      userId: $userId
      pagination: { page: $page, limit: $limit }
      filter: { mediaType: $mediaType, forceRefresh: $forceRefresh }
    ) {
      posts {
        id
        user_id
        content
        media {
          type
          url
          width
          height
          thumbnail
          duration
        }
        media_type
        stats {
          likes
          comments
          shares
          views
        }
        interactions {
          isLiked
          isFollowing
          isSaved
        }
        user {
          id
          name
          username
          profile_pic
          is_verified
          verification_badge {
            id
            name
            icon_url
            color
          }
        }
        suffix
        created_on
        updated_on
        status
        removal_status
      }
      pageInfo {
        currentPage
        totalPages
        hasNextPage
        hasPreviousPage
        totalCount
      }
      followStates {
        userId
        isFollowing
      }
      needsRefresh
    }
  }
''';

class FeedState {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final bool isRefreshing;
  final bool isFetchingMore;
  final bool hasNextPage;
  final int currentPage;
  final int totalCount;
  final String? error;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isFetchingMore = false,
    this.hasNextPage = false,
    this.currentPage = 1,
    this.totalCount = 0,
    this.error,
  });

  FeedState copyWith({
    List<Map<String, dynamic>>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? isFetchingMore,
    bool? hasNextPage,
    int? currentPage,
    int? totalCount,
    String? error,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      error: error,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final Ref ref;
  static const int pageSize = 10;

  FeedNotifier(this.ref) : super(const FeedState()) {
    // Listen to auth changes so when uid is ready, we load the feed automatically
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.uid != null && next.uid!.isNotEmpty && state.posts.isEmpty && !state.isLoading) {
        fetchInitialFeed();
      }
    });

    final uid = ref.read(authProvider).uid;
    if (uid != null && uid.isNotEmpty) {
      fetchInitialFeed();
    }
  }

  Future<void> fetchInitialFeed() async {
    final uid = ref.read(authProvider).uid ?? '';
    if (uid.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final res = await graphQLService.query(
        query: homeFeedQuery,
        variables: {
          'userId': uid,
          'page': 1,
          'limit': pageSize,
          'forceRefresh': false,
        },
      );

      final feedData = res['homeFeed'] as Map<String, dynamic>? ?? {};
      final postsList = (feedData['posts'] as List?) ?? [];
      final pageInfo = (feedData['pageInfo'] as Map<String, dynamic>?) ?? {};

      final parsedPosts = _transformPosts(postsList);

      state = state.copyWith(
        posts: parsedPosts,
        isLoading: false,
        currentPage: (pageInfo['currentPage'] as int?) ?? 1,
        hasNextPage: (pageInfo['hasNextPage'] as bool?) ?? false,
        totalCount: (pageInfo['totalCount'] as int?) ?? parsedPosts.length,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> refresh() async {
    final uid = ref.read(authProvider).uid ?? '';
    if (uid.isEmpty) return;

    state = state.copyWith(isRefreshing: true, error: null);

    try {
      final res = await graphQLService.query(
        query: homeFeedQuery,
        variables: {
          'userId': uid,
          'page': 1,
          'limit': pageSize,
          'forceRefresh': true,
        },
      );

      final feedData = res['homeFeed'] as Map<String, dynamic>? ?? {};
      final postsList = (feedData['posts'] as List?) ?? [];
      final pageInfo = (feedData['pageInfo'] as Map<String, dynamic>?) ?? {};

      final parsedPosts = _transformPosts(postsList);

      state = state.copyWith(
        posts: parsedPosts,
        isRefreshing: false,
        currentPage: (pageInfo['currentPage'] as int?) ?? 1,
        hasNextPage: (pageInfo['hasNextPage'] as bool?) ?? false,
        totalCount: (pageInfo['totalCount'] as int?) ?? parsedPosts.length,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNextPage || state.isFetchingMore || state.isLoading) return;

    final uid = ref.read(authProvider).uid ?? '';
    if (uid.isEmpty) return;

    final nextPage = state.currentPage + 1;
    state = state.copyWith(isFetchingMore: true);

    try {
      final res = await graphQLService.query(
        query: homeFeedQuery,
        variables: {
          'userId': uid,
          'page': nextPage,
          'limit': pageSize,
        },
      );

      final feedData = res['homeFeed'] as Map<String, dynamic>? ?? {};
      final postsList = (feedData['posts'] as List?) ?? [];
      final pageInfo = (feedData['pageInfo'] as Map<String, dynamic>?) ?? {};

      final newParsedPosts = _transformPosts(postsList);

      // Deduplicate posts by ID
      final existingIds = state.posts.map((p) => p['id'].toString()).toSet();
      final filteredNewPosts = newParsedPosts.where((p) => !existingIds.contains(p['id'].toString())).toList();

      state = state.copyWith(
        posts: [...state.posts, ...filteredNewPosts],
        isFetchingMore: false,
        currentPage: (pageInfo['currentPage'] as int?) ?? nextPage,
        hasNextPage: (pageInfo['hasNextPage'] as bool?) ?? false,
        totalCount: (pageInfo['totalCount'] as int?) ?? (state.posts.length + filteredNewPosts.length),
      );
    } catch (e) {
      state = state.copyWith(isFetchingMore: false);
    }
  }

  List<Map<String, dynamic>> _transformPosts(List rawList) {
    return rawList.map<Map<String, dynamic>>((item) {
      final p = Map<String, dynamic>.from(item as Map);
      final stats = (p['stats'] as Map<String, dynamic>?) ?? {};
      final interactions = (p['interactions'] as Map<String, dynamic>?) ?? {};

      return {
        ...p,
        'likes': stats['likes'] ?? 0,
        'comments': stats['comments'] ?? 0,
        'shares': stats['shares'] ?? 0,
        'views': stats['views'] ?? 0,
        'isLiked': interactions['isLiked'] == true,
        'isSaved': interactions['isSaved'] == true,
        'isFollowing': interactions['isFollowing'] == true,
      };
    }).toList();
  }

  void updateLike(String postId, bool isLiked, int count) {
    final idx = state.posts.indexWhere((p) => p['id'].toString() == postId);
    if (idx == -1) return;

    final updatedList = List<Map<String, dynamic>>.from(state.posts);
    updatedList[idx] = {
      ...updatedList[idx],
      'isLiked': isLiked,
      'likes': count,
    };
    state = state.copyWith(posts: updatedList);
  }

  void updateComments(String postId, int count) {
    final idx = state.posts.indexWhere((p) => p['id'].toString() == postId);
    if (idx == -1) return;

    final updatedList = List<Map<String, dynamic>>.from(state.posts);
    updatedList[idx] = {
      ...updatedList[idx],
      'comments': count,
    };
    state = state.copyWith(posts: updatedList);
  }
}

final feedNotifierProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref);
});
