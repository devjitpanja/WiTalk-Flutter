import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import 'auth_provider.dart';

class NotificationItem {
  final String id;
  final String type;
  final String? referenceType;
  final dynamic referenceId;
  final String? actorId;
  final String? actorName;
  final String? actorProfilePic;
  final String? actorProfilePicMedium;
  final String? message;
  final String? thumbnailUrl;
  final bool isRead;
  final bool isSeen;
  final String? createdAt;
  final Map<String, dynamic>? data;
  final String? actionUrl;

  const NotificationItem({
    required this.id,
    required this.type,
    this.referenceType,
    this.referenceId,
    this.actorId,
    this.actorName,
    this.actorProfilePic,
    this.actorProfilePicMedium,
    this.message,
    this.thumbnailUrl,
    required this.isRead,
    required this.isSeen,
    this.createdAt,
    this.data,
    this.actionUrl,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      parsedData = rawData;
    } else if (rawData is String && rawData.isNotEmpty) {
      try {
        parsedData = jsonDecode(rawData) as Map<String, dynamic>?;
      } catch (_) {}
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id'],
      actorId: json['actor_id']?.toString(),
      actorName: json['actor_name']?.toString(),
      actorProfilePic: json['actor_profile_pic']?.toString(),
      actorProfilePicMedium: json['actor_profile_pic_medium']?.toString(),
      message: json['message']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      isRead: json['is_read'] == true,
      isSeen: json['is_seen'] == true,
      createdAt: json['created_at']?.toString(),
      data: parsedData,
      actionUrl: json['action_url']?.toString(),
    );
  }

  NotificationItem copyWith({bool? isRead, bool? isSeen}) => NotificationItem(
        id: id,
        type: type,
        referenceType: referenceType,
        referenceId: referenceId,
        actorId: actorId,
        actorName: actorName,
        actorProfilePic: actorProfilePic,
        actorProfilePicMedium: actorProfilePicMedium,
        message: message,
        thumbnailUrl: thumbnailUrl,
        isRead: isRead ?? this.isRead,
        isSeen: isSeen ?? this.isSeen,
        createdAt: createdAt,
        data: data,
        actionUrl: actionUrl,
      );
}

class NotificationState {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final int unseenCount;
  final bool loading;
  final bool refreshing;
  final bool hasMore;
  final int offset;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.unseenCount = 0,
    this.loading = false,
    this.refreshing = false,
    this.hasMore = true,
    this.offset = 0,
  });

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    int? unreadCount,
    int? unseenCount,
    bool? loading,
    bool? refreshing,
    bool? hasMore,
    int? offset,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        unreadCount: unreadCount ?? this.unreadCount,
        unseenCount: unseenCount ?? this.unseenCount,
        loading: loading ?? this.loading,
        refreshing: refreshing ?? this.refreshing,
        hasMore: hasMore ?? this.hasMore,
        offset: offset ?? this.offset,
      );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final String userId;
  Timer? _pollingTimer;

  // IDs that have been marked read locally — used to override stale server
  // responses that may still return is_read: false due to server caching or
  // race conditions between our mark call and the next fetch.
  final _localReadIds = <String>{};

  NotificationNotifier(this.userId) : super(const NotificationState()) {
    debugPrint('[NotifProvider] 🟢 Notifier CREATED for userId=$userId');
    _init();
  }

  void _init() {
    debugPrint('[NotifProvider] 🔄 _init: fetching notifications fresh from server');
    fetchNotifications(isRefresh: true);
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _fetchCounts();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchCounts());
  }

  Future<void> _fetchCounts() async {
    try {
      final res = await dioClient.get('/v1/notifications/$userId/counts');
      final data = res.data['data'];
      if (data != null) {
        state = state.copyWith(
          unreadCount: (data['unread'] as int?) ?? 0,
          unseenCount: (data['unseen'] as int?) ?? 0,
        );
      }
    } catch (_) {}
  }

  Future<void> fetchNotifications({bool isRefresh = false}) async {
    if (state.loading && !isRefresh) return;

    if (isRefresh) {
      state = state.copyWith(refreshing: true, offset: 0);
    } else {
      state = state.copyWith(loading: true);
    }

    try {
      const limit = 20;
      final currentOffset = isRefresh ? 0 : state.offset;
      final res = await dioClient.get(
        '/v1/notifications/$userId',
        queryParameters: {'limit': limit, 'offset': currentOffset},
      );
      final responseData = res.data['data'];
      final List<dynamic> rawList = responseData['notifications'] as List? ?? [];
      // Apply local read overrides: if we already marked an ID as read locally,
      // force isRead=true even if the server still returns false (race condition).
      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((json) {
            final item = NotificationItem.fromJson(json);
            if (!item.isRead && _localReadIds.contains(item.id)) {
              debugPrint('[NotifProvider] fetch override: id=${item.id} forced isRead=true (local cache)');
              return item.copyWith(isRead: true);
            }
            return item;
          })
          .toList();

      final hasMore = responseData['pagination']?['hasMore'] == true;

      if (isRefresh) {
        state = state.copyWith(
          notifications: items,
          hasMore: hasMore,
          offset: limit,
          refreshing: false,
          loading: false,
        );
      } else {
        final existing = Set<String>.from(state.notifications.map((n) => n.id));
        final fresh = items.where((n) => !existing.contains(n.id)).toList();
        state = state.copyWith(
          notifications: [...state.notifications, ...fresh],
          hasMore: hasMore,
          offset: state.offset + limit,
          loading: false,
        );
      }
    } catch (_) {
      state = state.copyWith(loading: false, refreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.loading && state.hasMore) {
      await fetchNotifications(isRefresh: false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    debugPrint('[NotifProvider] markAsRead: id=$notificationId → calling API');
    // Mark locally first so any concurrent/subsequent fetch won't re-show as unread
    _localReadIds.add(notificationId);
    // Optimistic UI update immediately
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
          .toList(),
      unreadCount: (state.unreadCount - 1).clamp(0, 99999),
    );
    try {
      await dioClient.put('/v1/notifications/$notificationId/read', data: {'userId': userId});
      debugPrint('[NotifProvider] markAsRead: ✅ API success for id=$notificationId');
      _fetchCounts();
    } catch (e) {
      debugPrint('[NotifProvider] markAsRead: ❌ API FAILED for id=$notificationId error=$e');
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic: mark all current IDs locally before API call
    for (final n in state.notifications) {
      _localReadIds.add(n.id);
    }
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
      unreadCount: 0,
    );
    try {
      await dioClient.put('/v1/notifications/read-all', data: {'userId': userId});
    } catch (_) {}
  }

  Future<void> markAllAsSeen() async {
    try {
      await dioClient.put('/v1/notifications/seen-all', data: {'userId': userId});
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.copyWith(isSeen: true)).toList(),
        unseenCount: 0,
      );
    } catch (_) {}
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await dioClient.delete(
        '/v1/notifications/$notificationId',
        data: {'userId': userId},
      );
      state = state.copyWith(
        notifications: state.notifications.where((n) => n.id != notificationId).toList(),
      );
      _fetchCounts();
      return true;
    } catch (_) {
      return false;
    }
  }

  void refreshCounts() => _fetchCounts();

  @override
  void dispose() {
    debugPrint('[NotifProvider] 🔴 Notifier DISPOSED — in-memory read state LOST. Next open fetches server state.');
    _pollingTimer?.cancel();
    super.dispose();
  }
}

// Not autoDispose — matches RN NotificationContext which is a global provider
// that lives for the entire app lifetime. autoDispose was causing the notifier
// to be destroyed every time the screen was popped, wiping in-memory isRead
// state and re-fetching from server, making already-read items re-appear as unread.
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final uid = ref.watch(authProvider).uid ?? '';
  return NotificationNotifier(uid);
});
