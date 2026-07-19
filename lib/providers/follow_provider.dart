import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/dio_client.dart';

class FollowState {
  // userId -> isFollowing
  final Map<String, bool> followStates;
  // userId -> isLoading
  final Map<String, bool> loadingStates;
  // userId -> follower count delta (applied on top of profile data)
  final Map<String, int> followerCounts;
  final String? currentUserId;

  const FollowState({
    this.followStates = const {},
    this.loadingStates = const {},
    this.followerCounts = const {},
    this.currentUserId,
  });

  FollowState copyWith({
    Map<String, bool>? followStates,
    Map<String, bool>? loadingStates,
    Map<String, int>? followerCounts,
    String? currentUserId,
  }) => FollowState(
    followStates: followStates ?? this.followStates,
    loadingStates: loadingStates ?? this.loadingStates,
    followerCounts: followerCounts ?? this.followerCounts,
    currentUserId: currentUserId ?? this.currentUserId,
  );

  bool getFollowState(String userId) => followStates[userId] ?? false;
  bool getLoadingState(String userId) => loadingStates[userId] ?? false;
  int getFollowerCount(String userId) => followerCounts[userId] ?? 0;
}

class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier() : super(const FollowState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid != null) {
      state = state.copyWith(currentUserId: uid);
    }
  }

  void setCurrentUser(String userId) {
    state = state.copyWith(currentUserId: userId);
  }

  void clearFollowStates() {
    state = const FollowState();
  }

  bool getFollowState(String userId) => state.getFollowState(userId);
  bool getLoadingState(String userId) => state.getLoadingState(userId);

  // Seed follower count from profile data — only sets it if not already tracked
  void seedFollowerCount(String userId, int count) {
    if (state.followerCounts.containsKey(userId)) return;
    final updated = Map<String, int>.from(state.followerCounts)..[userId] = count;
    state = state.copyWith(followerCounts: updated);
  }

  Future<bool> checkFollowStatus(String targetUserId) async {
    final myId = state.currentUserId;
    if (myId == null || myId.isEmpty || myId == targetUserId) return false;
    try {
      final res = await dioClient.get('/v1/followers/$myId/status/$targetUserId');
      bool isFollowing = false;
      final data = res.data;
      if (data?['data']?['isFollowing'] is bool) {
        isFollowing = data['data']['isFollowing'] as bool;
      } else if (data?['isFollowing'] is bool) {
        isFollowing = data['isFollowing'] as bool;
      }
      _updateFollowState(targetUserId, isFollowing);
      return isFollowing;
    } catch (_) {
      return state.getFollowState(targetUserId);
    }
  }

  // Optimistic toggle — updates locally immediately, reconciles from server response
  Future<({bool isFollowing, bool success})> toggleFollow(String targetUserId) async {
    final myId = state.currentUserId;
    if (myId == null || myId.isEmpty || myId == targetUserId) {
      return (isFollowing: state.getFollowState(targetUserId), success: false);
    }

    final currentState = state.getFollowState(targetUserId);
    final optimisticState = !currentState;

    // Optimistic update
    _updateFollowState(targetUserId, optimisticState);
    _setLoading(targetUserId, true);

    // Update follower count optimistically
    final currentCount = state.getFollowerCount(targetUserId);
    _updateFollowerCount(targetUserId, currentCount + (optimisticState ? 1 : -1));

    try {
      final res = await dioClient.post('/v1/followers/toggle', data: {
        'followingId': targetUserId,
        'followerId': myId,
      });

      bool serverState = optimisticState;
      bool success = false;
      final data = res.data;
      if (data != null) {
        if (data['data']?['isFollowing'] is bool) {
          serverState = data['data']['isFollowing'] as bool;
          success = true;
        } else if (data['isFollowing'] is bool) {
          serverState = data['isFollowing'] as bool;
          success = true;
        } else if (res.statusCode == 200) {
          serverState = optimisticState;
          success = true;
        }
      }

      // Reconcile if server disagrees
      if (serverState != optimisticState) {
        _updateFollowState(targetUserId, serverState);
        // Fix count too
        final delta = serverState ? 1 : -1;
        final base = state.getFollowerCount(targetUserId) - (optimisticState ? 1 : -1);
        _updateFollowerCount(targetUserId, base + delta);
      }

      return (isFollowing: serverState, success: success);
    } catch (_) {
      // Rollback on error
      _updateFollowState(targetUserId, currentState);
      _updateFollowerCount(targetUserId, currentCount);
      return (isFollowing: currentState, success: false);
    } finally {
      _setLoading(targetUserId, false);
    }
  }

  void _updateFollowState(String userId, bool isFollowing) {
    final updated = Map<String, bool>.from(state.followStates)..[userId] = isFollowing;
    state = state.copyWith(followStates: updated);
  }

  void _setLoading(String userId, bool loading) {
    final updated = Map<String, bool>.from(state.loadingStates)..[userId] = loading;
    state = state.copyWith(loadingStates: updated);
  }

  void _updateFollowerCount(String userId, int count) {
    final updated = Map<String, int>.from(state.followerCounts)..[userId] = count;
    state = state.copyWith(followerCounts: updated);
  }
}

final followProvider = StateNotifierProvider<FollowNotifier, FollowState>(
  (ref) => FollowNotifier(),
);
