import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api/app_endpoints.dart';
import '../api/dio_client.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';

// ---------------------------------------------------------------------------
// Mirrors RN: deepLinkHandler.js + App.jsx handleComplexDeepLink
//
// Supported patterns (witalk:// or https://witalk.in):
//
//   p/{suffix}          → PostViewScreen (Instagram-style: home first)
//   post/{postId}       → PostDetailScreen
//   m/{username}        → ChatConversationScreen (API call, create-or-get)
//   adda/{room_id}      → LiveAudioRoomScreen (API verify room)
//   group/{inviteCode}  → CommunityInfoScreen (public) or GroupInviteSheet
//   groupchat/{groupId} → GroupChatScreen
//   user/{username}     → UserProfileScreen
//   group-info/{id}     → GroupInfoScreen
//   followers/{userId}  → FollowersScreen
//   about/{username}    → UserProfileScreen (fallback)
//   system/voice-call   → VoiceCallScreen
//   system/video-call   → VideoCallScreen
//   system/random-chat  → RandomChatScreen
//   video/{videoId}     → FullscreenVideoScreen
//   mini/{videoId}      → MiniScreen
//   {handle}            → /v1/username/resolve/:handle → user/channel/group
//   Tab names           → shell tab navigation
//   Simple paths        → direct GoRouter push
// ---------------------------------------------------------------------------

// Group invite callback — set from main.dart so the service can show the sheet
// without importing GroupInviteSheet directly here.
typedef GroupInviteCallback = void Function(String inviteCode);
GroupInviteCallback? _onGroupInvite;
void setGroupInviteCallback(GroupInviteCallback cb) => _onGroupInvite = cb;

// Pending deep link: stored when user is not yet authenticated, processed after login.
String? _pendingUrlDeepLink;

void processPendingDeepLinkAfterLogin(BuildContext context) {
  if (_pendingUrlDeepLink != null) {
    final url = _pendingUrlDeepLink!;
    _pendingUrlDeepLink = null;
    AppLogger.log('[DeepLink] Processing pending link after login: $url');
    Future.delayed(const Duration(milliseconds: 600), () {
      handleDeepLink(context, url);
    });
  }
}

// ---------------------------------------------------------------------------
// Service lifecycle
// ---------------------------------------------------------------------------

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Call once from main.dart after the GoRouter is attached.
  /// [getContext] is a thunk that returns the current root [BuildContext].
  void init({required BuildContext Function() getContext}) {
    // Cold start (app launched by a deep link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        AppLogger.log('[DeepLink] Cold start URI: $uri');
        handleDeepLink(getContext(), uri.toString());
      }
    }).catchError((Object e) {
      AppLogger.error('[DeepLink] getInitialLink error', e);
    });

    // Warm start (link received while app is running)
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        AppLogger.log('[DeepLink] Warm start URI: $uri');
        handleDeepLink(getContext(), uri.toString());
      },
      onError: (Object e) => AppLogger.error('[DeepLink] uriLinkStream error', e),
    );
  }

  void dispose() => _sub?.cancel();
}

final deepLinkService = DeepLinkService.instance;

// ---------------------------------------------------------------------------
// Core handler — exact port of App.jsx handleComplexDeepLink
// ---------------------------------------------------------------------------

Future<void> handleDeepLink(BuildContext context, String url) async {
  if (!_isWiTalkLink(url)) return;
  final path = _extractPath(url);
  if (path == null) return;
  AppLogger.log('[DeepLink] Handling path: $path');

  // ── Post: p/{suffix} — Instagram style ────────────────────────────────────
  if (path.startsWith('p/')) {
    final suffix = path.substring(2);
    final uid = await AppStorage.get('uid') as String?;
    if (uid == null) { _pendingUrlDeepLink = url; return; }
    final router = GoRouter.of(context);
    final location = router.state?.matchedLocation ?? '';
    if (location != '/home') router.go('/home');
    await Future.delayed(const Duration(milliseconds: 300));
    if (context.mounted) context.push('/post-view/$suffix');
    return;
  }

  // ── PostDetail: post/{postId} ──────────────────────────────────────────────
  if (path.startsWith('post/')) {
    context.push('/post/${path.substring(5)}');
    return;
  }

  // ── Message: m/{username} — create-or-get conversation ────────────────────
  if (path.startsWith('m/')) {
    final username = path.substring(2);
    final uid = await AppStorage.get('uid') as String?;
    if (uid == null) { _pendingUrlDeepLink = url; return; }
    final currentUsername = await AppStorage.get('username') as String?;
    if (currentUsername != null && currentUsername == username) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.go('/account');
      return;
    }
    try {
      final userRes = await dioClient.get(AppEndpoints.findByUsername(username));
      if (userRes.data['success'] == true) {
        final targetUser = Map<String, dynamic>.from(userRes.data['data'] as Map);
        final convRes = await dioClient.post('/v1/chat/conversations', data: {
          'user1_id': uid,
          'user2_id': targetUser['id'],
        });
        if (convRes.data['success'] == true) {
          final conv = Map<String, dynamic>.from(convRes.data['data'] as Map);
          await Future.delayed(const Duration(milliseconds: 100));
          if (context.mounted) {
            context.push('/chat/conversation/${conv['id']}', extra: {
              'otherUser': {
                'id': targetUser['id'],
                'name': targetUser['name'],
                'username': targetUser['username'],
                'profile_pic': targetUser['profile_pic'],
              },
              'status': conv['status'],
              'initiatorId': conv['initiator_id'],
            });
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.error('[DeepLink] m/ handler error', e);
    }
    if (context.mounted) context.push('/profile/$username');
    return;
  }

  // ── Adda: adda/{room_id} — verify room ────────────────────────────────────
  if (path.startsWith('adda/')) {
    final roomId = path.substring(5);
    final uid = await AppStorage.get('uid') as String?;
    if (uid == null) { _pendingUrlDeepLink = url; return; }
    try {
      final res = await dioClient.get(AppEndpoints.audioRoom(roomId));
      final body = res.data;
      final room = body is Map
          ? (body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : null)
          : null;
      if (room == null) { AppLogger.log('[DeepLink] Adda room not found'); return; }
      if (room['status'] == 'active') {
        final actualRoomId = room['room_id']?.toString() ?? roomId;
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          context.push('/live-audio/$actualRoomId', extra: {
            'is_host': room['host_uid'] == uid,
          });
        }
      } else {
        AppLogger.log('[DeepLink] Adda room not active');
      }
    } catch (e) {
      AppLogger.error('[DeepLink] adda/ handler error', e);
    }
    return;
  }

  // ── Group invite: group/{inviteCode} ──────────────────────────────────────
  if (path.startsWith('group/')) {
    final inviteCode = path.substring(6);
    final uid = await AppStorage.get('uid') as String?;
    if (uid == null) { _pendingUrlDeepLink = url; return; }
    try {
      final res = await dioClient.get(AppEndpoints.groupByInviteCode(inviteCode));
      final raw = res.data;
      final groupData = raw is Map
          ? (raw['data'] is Map
              ? Map<String, dynamic>.from(raw['data'] as Map)
              : raw['group'] is Map
                  ? Map<String, dynamic>.from(raw['group'] as Map)
                  : null)
          : null;
      final isPublic = groupData?['entity_type'] == 'community' ||
          groupData?['group_type'] == 'public';
      if (isPublic) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) context.push('/community-info/$inviteCode');
      } else {
        _onGroupInvite?.call(inviteCode);
      }
    } catch (_) {
      _onGroupInvite?.call(inviteCode);
    }
    return;
  }

  // ── GroupChat: groupchat/{groupId} ────────────────────────────────────────
  if (path.startsWith('groupchat/')) {
    context.push('/chat/group/${path.substring(10)}');
    return;
  }

  // ── System deep links ─────────────────────────────────────────────────────
  if (path.startsWith('system/')) {
    switch (path.substring(7)) {
      case 'voice-call': context.push('/voice-call/system'); break;
      case 'video-call': context.push('/video-call/system'); break;
      case 'random-chat': context.push('/random-chat'); break;
    }
    return;
  }

  // ── Video: video/{videoId} ────────────────────────────────────────────────
  if (path.startsWith('video/')) {
    context.push('/fullscreen-video?url=${Uri.encodeComponent(path.substring(6))}');
    return;
  }

  // ── Mini viewer: mini/{videoId} ───────────────────────────────────────────
  if (path.startsWith('mini/')) {
    context.push('/mini');
    return;
  }

  // ── User profile: user/{username} ─────────────────────────────────────────
  if (path.startsWith('user/')) {
    final username = path.substring(5);
    final currentUsername = await AppStorage.get('username') as String?;
    if (!context.mounted) return;
    if (currentUsername != null && currentUsername == username) {
      context.go('/account');
    } else {
      context.push('/profile/$username');
    }
    return;
  }

  // ── Group info: group-info/{groupId} ─────────────────────────────────────
  if (path.startsWith('group-info/')) {
    context.push('/chat/group-info/${path.substring(11)}');
    return;
  }

  // ── Followers: followers/{userId} ─────────────────────────────────────────
  if (path.startsWith('followers/')) {
    context.push('/followers/${path.substring(10)}');
    return;
  }

  // ── About account: about/{username} ──────────────────────────────────────
  if (path.startsWith('about/')) {
    context.push('/profile/${path.substring(6)}');
    return;
  }

  // ── Tab screens ───────────────────────────────────────────────────────────
  const tabMap = {
    'home': '/home',
    'search': '/explore',
    'chats': '/chat',
    'notifications': '/notifications',
    'profile': '/account',
    'adda': '/adda',
  };
  if (tabMap.containsKey(path)) {
    context.go(tabMap[path]!);
    return;
  }

  // ── Simple named screens ──────────────────────────────────────────────────
  const simpleMap = {
    'create-post': '/create-post',
    'edit-profile': '/edit-profile',
    'account-overview': '/account-overview',
    'visitors': '/visitors',
    'likes': '/likes',
    'saved': '/saved',
    'missions': '/missions',
    'rank': '/rank',
    'ranking-rules': '/ranking-rules',
    'id-verification': '/id-verification',
    'settings/notifications': '/settings/notifications',
    'settings/content': '/settings/content',
    'search-result': '/search-result',
    'feedback': '/bugs-suggestions',
    'bugs-suggestions': '/bugs-suggestions',
    'menu/missions': '/missions',
    'menu/rank': '/rank',
    'menu/ranking-rules': '/ranking-rules',
    'menu/tutorial': '/tutorial',
    'menu/rewards': '/rewards',
    'menu/privacy': '/settings/message-privacy',
    'menu/referral': '/referral',
    'menu/wallet': '/wallet',
    'menu/streak': '/streak',
    'menu/merit': '/merit',
    'menu/account': '/account-settings',
    'menu/pass': '/pass',
  };
  if (simpleMap.containsKey(path)) {
    context.push(simpleMap[path]!);
    return;
  }

  // ── Universal handle: /{handle} → resolve user / channel / group ──────────
  if (!path.contains('/')) {
    const systemPaths = {
      'p', 'm', 'group', 'adda', 'system', 'auth', 'home', 'search',
      'chats', 'notifications', 'profile', 'post', 'create-post',
      'video', 'mini',
    };
    if (!systemPaths.contains(path)) {
      final handleRegex = RegExp(r'^[a-z0-9_\-]{3,30}$');
      if (!handleRegex.hasMatch(path.toLowerCase())) return;
      final uid = await AppStorage.get('uid') as String?;
      if (uid == null) { _pendingUrlDeepLink = url; return; }
      try {
        final res = await dioClient.get('${AppEndpoints.resolveUsername}/$path');
        final type = res.data['type'] as String?;
        final data = res.data['data'] is Map
            ? Map<String, dynamic>.from(res.data['data'] as Map)
            : null;
        if (!context.mounted || data == null) return;
        final currentUsername = await AppStorage.get('username') as String?;
        if (type == 'user') {
          if (currentUsername != null && currentUsername == data['username']) {
            context.go('/account');
          } else {
            context.push('/profile/${data['username']}');
          }
        } else if (type == 'channel') {
          context.push('/channel/${data['id']}', extra: {'channel': data});
        } else if (type == 'group') {
          context.push('/community-info/${data['invite_code']}');
        }
      } catch (e) {
        AppLogger.error('[DeepLink] handle resolve error', e);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Notification navigation — exact port of App.jsx handleNotificationNavigation
// ---------------------------------------------------------------------------

Future<void> handleNotificationNavigation(
  BuildContext context,
  Map<String, dynamic> rawData,
) async {
  // Normalise shape: prefer nested `data` sub-map when it carries `type`.
  final notif = (rawData['data'] is Map &&
          (rawData['data'] as Map)['type'] != null)
      ? Map<String, dynamic>.from(rawData['data'] as Map)
      : rawData;

  final notifType =
      (notif['notification_type'] ?? notif['type']) as String?;
  final referenceId =
      (notif['reference_id'] ?? notif['referenceId']) as String?;
  final senderUsername = notif['sender_username'] as String?;

  AppLogger.log('[DeepLink/Notif] type=$notifType  refId=$referenceId');
  if (notifType == null) return;

  switch (notifType) {

    // ── Private message ──────────────────────────────────────────────────────
    case 'message':
      await _navigateToConversation(context, notif, senderUsername, referenceId);

    // ── Message request / accepted ──────────────────────────────────────────
    case 'message_request_accepted':
    case 'message_request':
      final convId = (notif['conversationId'] ?? referenceId) as String?;
      if (convId != null) {
        await _pushConversationById(
          context, convId,
          status: notifType == 'message_request_accepted' ? 'active' : null,
          initiatorId: notif['initiator_id'] as String?,
        );
      }

    // ── Group message / topic ────────────────────────────────────────────────
    case 'group_message':
      final topicNotifType = notif['notifType'] as String?;
      final topicId = notif['topicId'] as String?;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!context.mounted) return;
      if ((topicNotifType == 'topic_created' ||
              topicNotifType == 'topic_reply') &&
          topicId != null &&
          referenceId != null) {
        context.push('/chat/group-topics/$referenceId/$topicId');
      } else if (referenceId != null) {
        context.push('/chat/group/$referenceId');
      }

    // ── Topic upvote ────────────────────────────────────────────────────────
    case 'topic_upvote':
    case 'reply_upvote':
      final topicId = notif['topicId'] as String?;
      final groupId =
          (notif['groupId'] ?? notif['referenceId'] ?? referenceId) as String?;
      if (topicId != null && groupId != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.push('/chat/group-topics/$groupId/$topicId');
      }

    // ── Post ─────────────────────────────────────────────────────────────────
    case 'post':
      final postSuffix =
          (notif['suffix'] ?? notif['postSuffix']) as String?;
      if (postSuffix != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.push('/post-view/$postSuffix');
      }

    // ── Like ─────────────────────────────────────────────────────────────────
    case 'like':
      final notifData = _notifDataMap(notif);
      final postSuffix =
          (notifData?['postSuffix'] ?? notif['postSuffix']) as String?;
      if (postSuffix != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.push('/post-view/$postSuffix');
      }

    // ── Comment / Comment Reply ──────────────────────────────────────────────
    case 'comment':
    case 'comment_reply':
      final notifData = _notifDataMap(notif);
      final postSuffix =
          (notifData?['postSuffix'] ?? notif['postSuffix']) as String?;
      if (postSuffix != null) {
        final commentId =
            referenceId != null ? int.tryParse(referenceId) : null;
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          final q = commentId != null ? '?commentId=$commentId' : '';
          context.push('/post-view/$postSuffix$q');
        }
      }

    // ── Follow ───────────────────────────────────────────────────────────────
    case 'follow':
      final actorId = (notif['actor_id'] ?? notif['actorId']) as String?;
      if (actorId != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.push('/profile/$actorId');
      }

    // ── Profile visit ────────────────────────────────────────────────────────
    case 'profile_visit':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.push('/visitors');

    // ── Channel message ──────────────────────────────────────────────────────
    case 'channel_message':
      final channelId = notif['channel_id'] as String?;
      if (channelId != null) {
        final channelName = (notif['channel_name'] ?? 'Channel') as String;
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          context.push('/channel/$channelId',
              extra: {'channel': {'id': channelId, 'name': channelName}});
        }
      }

    // ── Adda ─────────────────────────────────────────────────────────────────
    case 'adda':
      final roomId = (notif['room_id'] ?? referenceId) as String?;
      if (roomId != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.push('/live-audio/$roomId', extra: {'is_host': false});
      }

    // ── Stranger match ───────────────────────────────────────────────────────
    case 'stranger_match':
      final roomType = notif['room_type'] as String?;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!context.mounted) return;
      if (roomType == 'random_chat') context.push('/random-chat');
      else if (roomType == 'voice_call') context.push('/voice-call/system');
      else if (roomType == 'video_call') context.push('/video-call/system');

    // ── Verification ─────────────────────────────────────────────────────────
    case 'verification_approved':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.go('/account');

    case 'verification_rejected':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.push('/id-verification');

    // ── Missions ─────────────────────────────────────────────────────────────
    case 'mission_completed':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.push('/missions');

    // ── Wallet ───────────────────────────────────────────────────────────────
    case 'wallet':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.push('/wallet');

    // ── Rank ─────────────────────────────────────────────────────────────────
    case 'rank_refresh':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.push('/rank');

    // ── Group join / member added ────────────────────────────────────────────
    case 'group_join_approved':
    case 'group_member_added':
      if (referenceId != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) context.push('/chat/group/$referenceId');
      }

    // ── Message reaction ─────────────────────────────────────────────────────
    case 'message_reaction':
      if (referenceId != null) await _pushConversationById(context, referenceId);

    // ── Streak reminder ──────────────────────────────────────────────────────
    case 'streak_reminder':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.go('/adda');

    // ── Profile like ─────────────────────────────────────────────────────────
    case 'profile_like':
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.go('/chat');

    // ── Onboarding incomplete ────────────────────────────────────────────────
    case 'onboarding_incomplete':
      final screen = (notif['screen'] ?? 'complete-profile') as String;
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) context.push('/$screen');

    default:
      AppLogger.log('[DeepLink/Notif] Unknown type: $notifType');
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

bool _isWiTalkLink(String url) {
  if (url.startsWith('witalk://')) return true;
  try {
    final uri = Uri.parse(url);
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.host == 'witalk.in' || uri.host == 'www.witalk.in');
  } catch (_) {
    return false;
  }
}

String? _extractPath(String url) {
  try {
    if (url.startsWith('witalk://')) {
      return url.replaceFirst('witalk://', '').replaceAll(RegExp(r'^/|/$'), '');
    }
    final uri = Uri.parse(url);
    return uri.path.replaceAll(RegExp(r'^/|/$'), '');
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _notifDataMap(Map<String, dynamic> notif) {
  final raw = notif['data'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) {}
  }
  return null;
}

Future<void> _navigateToConversation(
  BuildContext context,
  Map<String, dynamic> notif,
  String? senderUsername,
  String? referenceId,
) async {
  final uid = await AppStorage.get('uid') as String?;
  if (uid == null) return;

  if (senderUsername != null) {
    final currentUsername = await AppStorage.get('username') as String?;
    if (currentUsername == senderUsername) return;
    try {
      final userRes = await dioClient.get(AppEndpoints.findByUsername(senderUsername));
      if (userRes.data['success'] == true) {
        final targetUser = Map<String, dynamic>.from(userRes.data['data'] as Map);
        final convRes = await dioClient.post('/v1/chat/conversations', data: {
          'user1_id': uid,
          'user2_id': targetUser['id'],
        });
        if (convRes.data['success'] == true) {
          final conv = Map<String, dynamic>.from(convRes.data['data'] as Map);
          await Future.delayed(const Duration(milliseconds: 100));
          if (context.mounted) {
            context.push('/chat/conversation/${conv['id']}', extra: {
              'otherUser': {
                'id': targetUser['id'],
                'name': targetUser['name'],
                'username': targetUser['username'],
                'profile_pic': targetUser['profile_pic'],
              },
            });
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.error('[DeepLink] _navigateToConversation username error', e);
    }
  }

  if (referenceId != null) {
    await _pushConversationById(context, referenceId);
  }
}

Future<void> _pushConversationById(
  BuildContext context,
  String convId, {
  String? status,
  String? initiatorId,
}) async {
  try {
    final uid = await AppStorage.get('uid') as String?;
    if (uid == null) return;
    final res = await dioClient.get('/v1/chat/conversations/$convId');
    if (res.data['success'] == true) {
      final conv = Map<String, dynamic>.from(res.data['data'] as Map);
      final otherUser = conv['user1_id'] == uid
          ? {
              'id': conv['user2_id'],
              'name': conv['user2_name'],
              'username': conv['user2_username'],
              'profile_pic': conv['user2_profile_pic'],
            }
          : {
              'id': conv['user1_id'],
              'name': conv['user1_name'],
              'username': conv['user1_username'],
              'profile_pic': conv['user1_profile_pic'],
            };
      await Future.delayed(const Duration(milliseconds: 100));
      if (context.mounted) {
        context.push('/chat/conversation/$convId', extra: {
          'otherUser': otherUser,
          if (status != null) 'status': status,
          if (initiatorId != null) 'initiatorId': initiatorId,
        });
      }
    }
  } catch (e) {
    AppLogger.error('[DeepLink] _pushConversationById error', e);
  }
}
