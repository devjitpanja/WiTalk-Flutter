import 'dart:math';
import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import '../api/graphql_service.dart';

/// Service to send recommendation algorithm feedback to the backend.
/// Ports logic from React Native's usePostFeedback.js & postsV2.js
class PostFeedbackService {
  static final PostFeedbackService _instance = PostFeedbackService._internal();
  factory PostFeedbackService() => _instance;
  PostFeedbackService._internal();

  final Map<String, int> _viewStartTimes = {};
  late final String _sessionId = _generateSessionId();

  String _generateSessionId() {
    final r = Random();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randStr = List.generate(9, (_) => chars[r.nextInt(chars.length)]).join();
    return 'session_${DateTime.now().millisecondsSinceEpoch}_$randStr';
  }

  void startViewTracking(String postId) {
    if (!_viewStartTimes.containsKey(postId)) {
      _viewStartTimes[postId] = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> endViewTracking(
    String userId,
    String postId, {
    int? position,
    String feedContext = 'recommended',
  }) async {
    final startTime = _viewStartTimes.remove(postId);
    if (startTime == null || userId.isEmpty) return;

    final viewDurationSeconds = ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).round();
    if (viewDurationSeconds < 1) return;

    final feedbackType = viewDurationSeconds >= 3 ? 'viewed' : 'skipped';

    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: feedbackType,
      metadata: {
        'viewDuration': viewDurationSeconds,
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
        'scrollDepth': 100,
      },
    );
  }

  Future<void> sendLikeFeedback({
    required String userId,
    required String postId,
    int? position,
    String feedContext = 'recommended',
  }) async {
    final startTime = _viewStartTimes[postId];
    final duration = startTime != null ? ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).round() : 0;

    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: 'liked',
      metadata: {
        'viewDuration': duration,
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
        'clickedThrough': true,
      },
    );
  }

  Future<void> sendCommentFeedback({
    required String userId,
    required String postId,
    int? position,
    String feedContext = 'recommended',
  }) async {
    final startTime = _viewStartTimes[postId];
    final duration = startTime != null ? ((DateTime.now().millisecondsSinceEpoch - startTime) / 1000).round() : 0;

    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: 'commented',
      metadata: {
        'viewDuration': duration,
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
        'clickedThrough': true,
      },
    );
  }

  Future<void> sendShareFeedback({
    required String userId,
    required String postId,
    int? position,
    String feedContext = 'recommended',
  }) async {
    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: 'share',
      metadata: {
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
        'clickedThrough': true,
      },
    );
  }

  Future<void> sendSaveFeedback({
    required String userId,
    required String postId,
    int? position,
    String feedContext = 'recommended',
  }) async {
    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: 'save',
      metadata: {
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
        'clickedThrough': true,
      },
    );
  }

  Future<void> sendNotInterestedFeedback({
    required String userId,
    required String postId,
    int? position,
    String feedContext = 'recommended',
  }) async {
    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: 'not_interested',
      metadata: {
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
      },
    );
  }

  Future<void> sendHidePostFeedback({
    required String userId,
    required String postId,
    int? position,
    String feedContext = 'recommended',
  }) async {
    await sendFeedback(
      userId: userId,
      postId: postId,
      feedbackType: 'hide_post',
      metadata: {
        'viewDuration': 0,
        'position': position,
        'feedContext': feedContext,
        'sessionId': _sessionId,
      },
    );
  }

  /// Core method to send feedback via API v2 with fallback to GraphQL mutation
  Future<void> sendFeedback({
    required String userId,
    required String postId,
    required String feedbackType,
    Map<String, dynamic>? metadata,
  }) async {
    final parsedPostId = int.tryParse(postId) ?? 0;
    if (parsedPostId == 0 || userId.isEmpty) return;

    try {
      // Try REST API v2 first
      await dioClient.post('/v2/posts/feedback', data: {
        'user_id': userId,
        'post_id': parsedPostId,
        'feedback_type': feedbackType,
        if (metadata != null) 'metadata': metadata,
      });
      if (kDebugMode) {
        print('[PostFeedback] Sent $feedbackType feedback for post $postId');
      }
    } catch (_) {
      // Fallback to GraphQL provideFeedback mutation
      try {
        const mutation = r'''
          mutation ProvideFeedback($userId: ID!, $postId: Int!, $feedbackType: String!, $metadata: JSON) {
            provideFeedback(userId: $userId, postId: $postId, feedbackType: $feedbackType, metadata: $metadata)
          }
        ''';
        await graphQLService.query(
          query: mutation,
          variables: {
            'userId': userId,
            'postId': parsedPostId,
            'feedbackType': feedbackType,
            'metadata': metadata,
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('[PostFeedback] Error sending feedback: $e');
        }
      }
    }
  }
}

final postFeedbackService = PostFeedbackService();
