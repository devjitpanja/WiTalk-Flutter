import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_room_service.dart';
import 'auth_provider.dart';

class AddaState {
  final String activeTab; // 'live' | 'upcoming'
  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> groupedItems;
  final List<Map<String, dynamic>> upcomingRooms;
  final Map<String, bool> followingMap;
  final Map<String, bool> expandedCommunities;
  final Map<String, dynamic> addaSettings;
  final bool isLoadingLive;
  final bool isLoadingUpcoming;
  final bool isRefreshingLive;
  final bool isRefreshingUpcoming;
  final String? error;

  const AddaState({
    this.activeTab = 'live',
    this.rooms = const [],
    this.groupedItems = const [],
    this.upcomingRooms = const [],
    this.followingMap = const {},
    this.expandedCommunities = const {},
    this.addaSettings = const {
      'adda_server_enabled': true,
      'adda_creation_enabled': true,
      'adda_server_banner': '',
    },
    this.isLoadingLive = false,
    this.isLoadingUpcoming = false,
    this.isRefreshingLive = false,
    this.isRefreshingUpcoming = false,
    this.error,
  });

  AddaState copyWith({
    String? activeTab,
    List<Map<String, dynamic>>? rooms,
    List<Map<String, dynamic>>? groupedItems,
    List<Map<String, dynamic>>? upcomingRooms,
    Map<String, bool>? followingMap,
    Map<String, bool>? expandedCommunities,
    Map<String, dynamic>? addaSettings,
    bool? isLoadingLive,
    bool? isLoadingUpcoming,
    bool? isRefreshingLive,
    bool? isRefreshingUpcoming,
    String? error,
  }) {
    return AddaState(
      activeTab: activeTab ?? this.activeTab,
      rooms: rooms ?? this.rooms,
      groupedItems: groupedItems ?? this.groupedItems,
      upcomingRooms: upcomingRooms ?? this.upcomingRooms,
      followingMap: followingMap ?? this.followingMap,
      expandedCommunities: expandedCommunities ?? this.expandedCommunities,
      addaSettings: addaSettings ?? this.addaSettings,
      isLoadingLive: isLoadingLive ?? this.isLoadingLive,
      isLoadingUpcoming: isLoadingUpcoming ?? this.isLoadingUpcoming,
      isRefreshingLive: isRefreshingLive ?? this.isRefreshingLive,
      isRefreshingUpcoming: isRefreshingUpcoming ?? this.isRefreshingUpcoming,
      error: error,
    );
  }
}

class AddaNotifier extends StateNotifier<AddaState> {
  final Ref ref;

  AddaNotifier(this.ref) : super(const AddaState()) {
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    state = state.copyWith(isLoadingLive: true, isLoadingUpcoming: true);
    await Future.wait([
      fetchRooms(),
      fetchUpcomingRooms(),
      fetchAddaSettings(),
    ]);
  }

  Future<void> fetchRooms() async {
    final uid = ref.read(authProvider).uid ?? '';
    try {
      final res = await audioRoomService.getActiveRooms(limit: 50, offset: 0);
      if (res['success'] == true || res['data'] != null) {
        final rawRooms = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        // Filter out host's own room if logged in
        final filteredRooms = uid.isNotEmpty
            ? rawRooms.where((r) => r['host_uid']?.toString() != uid).toList()
            : rawRooms;

        final grouped = groupAddasByCommunity(filteredRooms);

        state = state.copyWith(
          rooms: filteredRooms,
          groupedItems: grouped,
          isLoadingLive: false,
          isRefreshingLive: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoadingLive: false, isRefreshingLive: false);
    }
  }

  Future<void> fetchUpcomingRooms() async {
    try {
      final res = await audioRoomService.getUpcomingRooms(limit: 30, offset: 0);
      if (res['success'] == true || res['data'] != null) {
        final upcoming = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final map = <String, bool>{};
        for (final r in upcoming) {
          final roomId = r['room_id']?.toString() ?? '';
          if (roomId.isNotEmpty) {
            map[roomId] = (r['is_following'] as int? ?? 0) > 0;
          }
        }

        state = state.copyWith(
          upcomingRooms: upcoming,
          followingMap: map,
          isLoadingUpcoming: false,
          isRefreshingUpcoming: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoadingUpcoming: false, isRefreshingUpcoming: false);
    }
  }

  Future<void> fetchAddaSettings() async {
    try {
      final res = await audioRoomService.getAddaSettings();
      final data = (res['data'] as Map<String, dynamic>?) ?? {};
      state = state.copyWith(addaSettings: data);
    } catch (_) {}
  }

  Future<void> refreshLive() async {
    state = state.copyWith(isRefreshingLive: true);
    await fetchRooms();
  }

  Future<void> refreshUpcoming() async {
    state = state.copyWith(isRefreshingUpcoming: true);
    await fetchUpcomingRooms();
  }

  void switchTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  void toggleCommunityExpand(String communityId) {
    final current = Map<String, bool>.from(state.expandedCommunities);
    current[communityId] = !(current[communityId] ?? false);
    state = state.copyWith(expandedCommunities: current);
  }

  Future<void> toggleFollowSchedule(String roomId) async {
    final currentMap = Map<String, bool>.from(state.followingMap);
    final currentlyFollowing = currentMap[roomId] ?? false;
    currentMap[roomId] = !currentlyFollowing;
    state = state.copyWith(followingMap: currentMap);

    try {
      await audioRoomService.toggleFollowSchedule(roomId);
    } catch (_) {
      // Revert on error
      currentMap[roomId] = currentlyFollowing;
      state = state.copyWith(followingMap: currentMap);
    }
  }

  /// Groups community addas by group_id; personal addas pass through as individual items.
  static List<Map<String, dynamic>> groupAddasByCommunity(List<Map<String, dynamic>> rooms) {
    final communityMap = <String, Map<String, dynamic>>{};
    final result = <Map<String, dynamic>>[];

    for (final room in rooms) {
      final groupId = room['group_id']?.toString();
      if (groupId != null && groupId.isNotEmpty) {
        if (!communityMap.containsKey(groupId)) {
          final entry = {
            'type': 'community',
            'communityId': groupId,
            'communityName': room['group_name'] ?? 'Community',
            'communityPicture': room['group_picture'],
            'memberCount': room['group_member_count'],
            'isMember': room['is_group_member'] == true || room['is_group_member'] == 1,
            'myJoinMethod': room['my_group_join_method'],
            'inviteCode': room['group_invite_code'],
            'passRequired': room['group_pass_required'] == true || room['group_pass_required'] == 1,
            'isMonetized': room['group_is_monetized'] == true || room['group_is_monetized'] == 1,
            'monetizationType': room['group_monetization_type'],
            'addas': <Map<String, dynamic>>[],
          };
          communityMap[groupId] = entry;
          result.add(entry);
        }
        (communityMap[groupId]!['addas'] as List<Map<String, dynamic>>).add(room);
      } else {
        result.add({'type': 'personal', 'room': room});
      }
    }

    return result;
  }
}

final addaNotifierProvider = StateNotifierProvider<AddaNotifier, AddaState>((ref) {
  return AddaNotifier(ref);
});
