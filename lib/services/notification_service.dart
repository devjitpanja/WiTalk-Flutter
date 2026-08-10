import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';
import '../api/dio_client.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';

const _fcmPrefsChannel = MethodChannel('com.witalk/fcm_prefs');

// ---------------------------------------------------------------------------
// Background message handler — must be a top-level function.
// The Kotlin WiTalkFCMService.kt handles the system tray notification itself;
// this handler is for any Dart-side side effects needed in background/terminated.
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // No extra Dart work needed — the native service builds the notification.
  AppLogger.log('[FCM] Background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// NotificationService
//
// Replaces the previous OneSignal-based implementation.
// Responsibilities:
//   1. Request permission (Android 13+, iOS)
//   2. Get / refresh FCM token and upload to backend
//   3. Display local notifications for foreground messages
//      (background/terminated → handled natively by WiTalkFCMService.kt)
//   4. Handle notification taps in all app states and route to correct screen
// ---------------------------------------------------------------------------
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging         = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Navigation callback — set from main.dart once the router is mounted.
  void Function(Map<String, dynamic>)? _onNotification;

  // Queue a tap that arrived before navigation was ready
  Map<String, dynamic>? _pendingNotification;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Register background handler before anything else
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Request permission
    await _requestPermission();

    // Initialize local notifications plugin (for foreground display)
    await _initLocalNotifications();

    // Foreground message handler — show local notification
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tap handlers
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Cold start: app launched by tapping a notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      AppLogger.log('[FCM] Cold-start notification: type=${initial.data['type']}');
      // Queued — will be dispatched once setNavigationHandler is called
      _pendingNotification = _normalisePayload(initial.data);
    }

    // Token management
    final token = await _messaging.getToken();
    if (token != null) {
      AppLogger.log('[FCM] Initial token: ${token.substring(0, 30)}...');
      await _saveTokenLocally(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      AppLogger.log('[FCM] Token refreshed');
      _saveTokenLocally(newToken);
    });
  }

  /// Called from main.dart after the GoRouter is attached.
  /// Flushes any pending cold-start tap immediately.
  void setNavigationHandler(void Function(Map<String, dynamic>) handler) {
    _onNotification = handler;
    if (_pendingNotification != null) {
      final pending = _pendingNotification!;
      _pendingNotification = null;
      handler(pending);
    }
  }

  /// Called on login — associates this device's FCM token with the user account.
  Future<void> setExternalUserId(String userId) async {
    try {
      final token    = await _messaging.getToken();
      final deviceId = await _getDeviceId();
      if (token == null) {
        AppLogger.log('[FCM] No token available yet — skipping upload');
        return;
      }

      // Save user_id in native SharedPreferences so WiTalkFCMService can read it
      // for inline reply actions (it needs the current user's ID).
      await _saveUserIdNative(userId);
      await _saveApiBaseUrlNative();

      await dioClient.post('/v1/fcm/token/register', data: {
        'token':      token,
        'deviceId':   deviceId,
        'deviceType': Platform.isAndroid ? 'android' : 'ios',
        'userId':     userId,
      });
      AppLogger.log('[FCM] Token uploaded for user $userId');
    } catch (e) {
      AppLogger.error('[FCM] Token upload failed', e);
    }
  }

  /// Called on logout — deletes FCM token from server and clears local cache.
  Future<void> logout() async {
    try {
      await _messaging.deleteToken();
      AppLogger.log('[FCM] Token deleted on logout');
    } catch (e) {
      AppLogger.error('[FCM] Error deleting token on logout', e);
    }
  }

  /// Clears all visible notifications from the tray.
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    AppLogger.log('[FCM] Permission: ${settings.authorizationStatus}');

    // On iOS, tell FCM to show foreground notifications natively
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ── Local notifications init ──────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    // Create the same channels here for local notification routing.
    // The definitive channel config lives in WiTalkFCMService.kt (Android O+);
    // these mirror settings are needed so flutter_local_notifications can pick
    // the right channel when we show a local notification.
    if (Platform.isAndroid) {
      await _ensureLocalChannels();
    }
  }

  Future<void> _ensureLocalChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    // We don't recreate channels here — WiTalkFCMService.kt owns creation.
    // We just need an AndroidNotificationDetails with the right channel ID.
    // The channels already exist after the native service runs onCreate().
  }

  // ── Foreground message ────────────────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    AppLogger.log('[FCM] Foreground: type=${message.data['type']}');

    final data = Map<String, String>.from(
      message.data.map((k, v) => MapEntry(k, v.toString())),
    );
    final type = data['type'] ?? '';

    // Suppress own broadcasts
    if (type == 'adda' && data['action'] == 'new_adda') {
      final myId = await AppStorage.get('uid') as String?;
      if (myId != null && data['hostId'] == myId) return;
    }
    if (type == 'channel_message') {
      final myId = await AppStorage.get('uid') as String?;
      if (myId != null && data['sender_id'] == myId) return;
    }

    // Adda in-room suppression
    if (_addaSuppressibleTypes.contains(type)) {
      final flag = await AppStorage.get('@is_in_adda') as String?;
      if (flag == 'true') return;
    }

    final title = data['title'] ?? message.notification?.title ?? 'WiTalk';
    final body  = data['body']  ?? message.notification?.body  ?? '';

    await _showLocalNotification(
      title:     title,
      body:      body,
      data:      data,
      channelId: _channelIdForType(type, data),
    );
  }

  static const _addaSuppressibleTypes = {
    'post', 'like', 'comment', 'comment_reply',
    'follow', 'social_interactions', 'adda',
    'topic_upvote', 'reply_upvote', 'profile_like',
    'profile_visit', 'referral', 'group_message', 'streak_reminder',
  };

  // ── Local notification display ────────────────────────────────────────────

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, String> data,
    required String channelId,
  }) async {
    final isSilent = data['silent'] == 'true'
        || data['type'] == 'profile_visit'
        || data['type'] == 'topic_upvote'
        || data['type'] == 'reply_upvote';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelNameForId(channelId),
      importance: isSilent ? Importance.low : Importance.high,
      priority:   isSilent ? Priority.low   : Priority.high,
      showWhen:   true,
      icon:       '@drawable/ic_notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notifId = _notifIdForData(data);
    final payload = _encodePayload(data);

    await _localNotifications.show(
      notifId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── Notification tap handlers ─────────────────────────────────────────────

  // Background tap (app was in background, user tapped)
  void _onNotificationTap(RemoteMessage message) {
    AppLogger.log('[FCM] Notification tapped (background): type=${message.data['type']}');
    _dispatch(_normalisePayload(message.data));
  }

  // Local notification tap (foreground notification the user tapped)
  void _onLocalNotifTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = _decodePayload(payload);
      AppLogger.log('[FCM] Local notification tapped: type=${data['type']}');
      _dispatch(data);
    } catch (e) {
      AppLogger.error('[FCM] Error decoding local notif payload', e);
    }
  }

  void _dispatch(Map<String, dynamic> data) {
    if (_onNotification != null) {
      _onNotification!(data);
    } else {
      _pendingNotification = data;
      AppLogger.log('[FCM] Navigation not ready — queuing notification');
    }
  }

  // ── Token persistence ─────────────────────────────────────────────────────

  Future<void> _saveTokenLocally(String token) async {
    await AppStorage.set('@fcm_token', token);
  }

  /// Writes the current user ID into native FCMPreferences so the Kotlin
  /// inline-reply receiver can read it without the Flutter engine running.
  Future<void> _saveUserIdNative(String userId) async {
    if (!Platform.isAndroid) return;
    try {
      await _fcmPrefsChannel.invokeMethod('saveUserId', {'userId': userId});
    } catch (_) {}
  }

  Future<void> _saveApiBaseUrlNative() async {
    if (!Platform.isAndroid) return;
    try {
      await _fcmPrefsChannel.invokeMethod('saveApiBaseUrl', {'url': AppConfig.apiBaseUrl});
    } catch (_) {}
  }

  // ── Device ID ────────────────────────────────────────────────────────────

  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      return (await info.androidInfo).id;
    } else {
      return (await info.iosInfo).identifierForVendor ?? '';
    }
  }

  // ── Channel helpers ───────────────────────────────────────────────────────

  String _channelIdForType(String type, Map<String, String> data) {
    final silent = data['silent'] == 'true';
    if (silent) return 'witalk_silent';
    switch (type) {
      case 'profile_visit':
      case 'topic_upvote':
      case 'reply_upvote':    return 'witalk_silent';
      case 'group_message':   return 'witalk_group_messages';
      case 'message':
      case 'message_request':
      case 'message_request_accepted': return 'witalk_messages';
      case 'profile_like':    return 'witalk_profile_likes';
      case 'match':           return 'witalk_matches';
      case 'social_interactions':
        if (data['action'] == 'nearby_join') return 'witalk_nearby_join';
        return 'witalk_social_interactions';
      case 'like':
      case 'comment':
      case 'comment_reply':
      case 'follow':          return 'witalk_social_interactions';
      case 'verification_approved':
      case 'verification_rejected':
      case 'system':          return 'witalk_system';
      case 'wallet':          return 'witalk_wallet';
      case 'streak_reminder': return 'witalk_streak';
      default:                return 'witalk_messages';
    }
  }

  String _channelNameForId(String id) {
    switch (id) {
      case 'witalk_messages':         return 'Private Messages';
      case 'witalk_group_messages':   return 'Group Messages';
      case 'witalk_profile_likes':    return 'Profile Likes';
      case 'witalk_matches':          return 'New Matches';
      case 'witalk_nearby_join':      return 'Nearby Users';
      case 'witalk_social_interactions': return 'Social Interactions';
      case 'witalk_system':           return 'System';
      case 'witalk_silent':           return 'Silent Notifications';
      case 'witalk_wallet':           return 'Wallet';
      case 'witalk_streak':           return 'Streak Reminders';
      default:                        return 'WiTalk';
    }
  }

  // ── Payload helpers ───────────────────────────────────────────────────────

  Map<String, dynamic> _normalisePayload(Map<String, dynamic> raw) {
    if (raw['data'] is Map && (raw['data'] as Map)['type'] != null) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    return raw;
  }

  int _notifIdForData(Map<String, String> data) {
    final chatId = data['conversationId'] ?? data['referenceId'] ?? data['groupId'];
    return chatId != null && chatId.isNotEmpty
        ? chatId.hashCode
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  String _encodePayload(Map<String, String> data) =>
      data.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

  Map<String, dynamic> _decodePayload(String payload) {
    return Map.fromEntries(
      payload.split('&').map((kv) {
        final parts = kv.split('=');
        return MapEntry(
          Uri.decodeComponent(parts[0]),
          parts.length > 1 ? Uri.decodeComponent(parts.sublist(1).join('=')) : '',
        );
      }),
    );
  }
}

final notificationService = NotificationService();
