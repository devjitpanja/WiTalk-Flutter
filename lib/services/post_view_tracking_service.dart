import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';

/// Service to track post view engagement, watch duration, and metrics.
/// Ports the logic from React Native's usePostViewTracking.js
class PostViewTrackingService {
  static final PostViewTrackingService _instance = PostViewTrackingService._internal();
  factory PostViewTrackingService() => _instance;
  PostViewTrackingService._internal();

  static const int minViewDurationMs = 3000; // 3 seconds
  static const int debounceTimeMs = 10000; // 10 seconds

  // Cache to track recently sent views (cacheKey -> timestamp)
  final Map<String, int> _recentlyTracked = {};

  // Active view sessions (postId -> ViewSession)
  final Map<String, ViewSession> _activeSessions = {};

  /// Start tracking a post when it enters the viewport
  void startTracking({
    required String postId,
    required String userId,
    String screenType = 'feed',
    String interactionType = 'scroll',
  }) {
    if (postId.isEmpty || userId.isEmpty) return;

    final key = '${postId}_$userId';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check debounce
    final lastTracked = _recentlyTracked[key];
    if (lastTracked != null && (now - lastTracked) < debounceTimeMs) {
      return;
    }

    final session = _activeSessions[key] ??
        ViewSession(
          postId: postId,
          userId: userId,
          screenType: screenType,
          interactionType: interactionType,
        );

    session.start(now);
    _activeSessions[key] = session;
  }

  /// Pause tracking when post leaves viewport
  void pauseTracking(String postId, String userId) {
    final key = '${postId}_$userId';
    final session = _activeSessions[key];
    if (session == null) return;

    session.pause(DateTime.now().millisecondsSinceEpoch);

    // If accumulated duration is >= 3 seconds, send data immediately
    if (session.watchDurationMs >= minViewDurationMs && !session.hasTracked) {
      stopAndSend(postId, userId);
    }
  }

  /// Stop tracking and submit data to backend
  Future<void> stopAndSend(
    String postId,
    String userId, {
    bool isCompleted = false,
    bool wasSkipped = false,
  }) async {
    final key = '${postId}_$userId';
    final session = _activeSessions.remove(key);
    if (session == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    session.stop(now);

    final duration = session.watchDurationMs;
    if (duration < minViewDurationMs) return;

    final cacheKey = '${postId}_$userId';
    _recentlyTracked[cacheKey] = now;

    final parsedPostId = int.tryParse(postId) ?? 0;
    if (parsedPostId == 0) return;

    final payload = {
      'post_id': parsedPostId,
      'user_id': userId,
      'watch_duration_ms': duration,
      'view_percentage': isCompleted ? 100 : 0,
      'is_completed': isCompleted,
      'was_skipped': wasSkipped || (duration < 5000 && !isCompleted),
      'interaction_type': session.interactionType,
      'screen_type': session.screenType,
      'device_type': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web'),
      'scroll_away_count': session.scrollAwayCount,
      'pause_count': session.pauseCount,
    };

    try {
      await dioClient.post('/v1/engagement/track-view', data: payload);
      if (kDebugMode) {
        print('[PostViewTracking] Sent view metrics for post $postId (${duration}ms)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostViewTracking] Failed to track view for post $postId: $e');
      }
    }
  }

  /// Record user pausing video/post
  void incrementPause(String postId, String userId) {
    final key = '${postId}_$userId';
    _activeSessions[key]?.pauseCount++;
  }
}

class ViewSession {
  final String postId;
  final String userId;
  final String screenType;
  final String interactionType;

  int? startTime;
  int watchDurationMs = 0;
  int scrollAwayCount = 0;
  int pauseCount = 0;
  bool hasTracked = false;

  ViewSession({
    required this.postId,
    required this.userId,
    required this.screenType,
    required this.interactionType,
  });

  void start(int timestamp) {
    startTime = timestamp;
  }

  void pause(int timestamp) {
    if (startTime != null) {
      watchDurationMs += (timestamp - startTime!);
      startTime = null;
      scrollAwayCount++;
    }
  }

  void stop(int timestamp) {
    if (startTime != null) {
      watchDurationMs += (timestamp - startTime!);
      startTime = null;
    }
    hasTracked = true;
  }
}

final postViewTrackingService = PostViewTrackingService();
