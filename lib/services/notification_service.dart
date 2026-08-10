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
// Background message handler — top-level, required by firebase_messaging.
// WiTalkFCMService.kt already shows the system tray notification natively, so
// no Dart work is needed here.
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  AppLogger.log('[FCM] Background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// NotificationService
//
// Architecture (mirrors RN):
//   Android: WiTalkFCMService.kt shows ALL notifications (foreground, background,
//            terminated). Dart only handles navigation routing on tap.
//   iOS:     flutter_local_notifications shows foreground banners (APNs suppresses
//            them by default while app is active; we re-show via local notif).
//            Background/terminated shown by APNs natively.
//
// Duplicate prevention:
//   On Android, _onForegroundMessage does NOT show a local notification — the
//   native service already did it. On iOS it does (APNs suppresses foreground).
//
// Clearing on foreground:
//   When app comes to foreground we call cancelAll() + clearHistory() via the
//   native MethodChannel, exactly like RN's AppState → active listener.
// ---------------------------------------------------------------------------
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging          = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  void Function(Map<String, dynamic>)? _onNotification;
  Map<String, dynamic>? _pendingNotification;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();

    // Foreground message:
    //   Android → native WiTalkFCMService.kt already showed the notification,
    //             so we only handle iOS here.
    //   iOS     → APNs suppresses foreground banners by default, so we show
    //             a local notification ourselves.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tap: app was in background, user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Cold start: app launched by tapping a terminated-state notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      AppLogger.log('[FCM] Cold-start tap: type=${initial.data['type']}');
      _pendingNotification = _normalisePayload(initial.data);
    }

    // Token
    final token = await _messaging.getToken();
    if (token != null) {
      AppLogger.log('[FCM] Initial token: ${token.substring(0, 30)}...');
      await _saveTokenLocally(token);
    }
    _messaging.onTokenRefresh.listen(_saveTokenLocally);
  }

  /// Set from main.dart after the router mounts. Flushes any queued cold-start tap.
  void setNavigationHandler(void Function(Map<String, dynamic>) handler) {
    _onNotification = handler;
    if (_pendingNotification != null) {
      final pending = _pendingNotification!;
      _pendingNotification = null;
      handler(pending);
    }
  }

  /// Called on login — uploads FCM token to backend.
  Future<void> setExternalUserId(String userId) async {
    try {
      final token    = await _messaging.getToken();
      final deviceId = await _getDeviceId();
      if (token == null) return;

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

  /// Called on logout.
  Future<void> logout() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      AppLogger.error('[FCM] Error deleting token', e);
    }
  }

  /// Called when app comes to foreground — clears tray and message history.
  /// Mirrors RN: AppState active → FCMService.clearAllNotifications() + clearNotificationHistory()
  Future<void> clearAllNotifications() async {
    if (Platform.isAndroid) {
      try {
        await _fcmPrefsChannel.invokeMethod('clearAllNotifications');
      } catch (_) {}
    } else {
      await _localNotifications.cancelAll();
    }
  }

  /// Clear notifications for a specific private chat conversation (call when chat is opened).
  Future<void> clearChatNotifications(String conversationId) async {
    if (Platform.isAndroid) {
      try {
        await _fcmPrefsChannel.invokeMethod(
            'clearChatNotifications', {'conversationId': conversationId});
      } catch (_) {}
    } else {
      await _localNotifications.cancel(conversationId.hashCode);
    }
  }

  /// Clear notifications for a specific group (call when group chat is opened).
  Future<void> clearGroupNotifications(String groupId) async {
    if (Platform.isAndroid) {
      try {
        await _fcmPrefsChannel.invokeMethod(
            'clearGroupNotifications', {'groupId': groupId});
      } catch (_) {}
    } else {
      await _localNotifications.cancel(groupId.hashCode);
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    AppLogger.log('[FCM] Permission: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false, // We show our own local notification below
        badge: true,
        sound: false,
      );
    }
  }

  // ── Local notifications (iOS foreground only) ─────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );
  }

  // ── Foreground message ────────────────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final type = message.data['type'] ?? '';
    AppLogger.log('[FCM] Foreground: type=$type');

    // Android: WiTalkFCMService.kt already showed the notification natively.
    // Nothing to do here except let the navigation handler fire on tap.
    if (Platform.isAndroid) return;

    // iOS: APNs suppresses foreground banners, so show via flutter_local_notifications.
    final data = Map<String, String>.from(
      message.data.map((k, v) => MapEntry(k, v.toString())),
    );

    // Suppress own broadcasts
    if (type == 'adda' && data['action'] == 'new_adda') {
      final myId = await AppStorage.get('uid') as String?;
      if (myId != null && data['hostId'] == myId) return;
    }
    if (type == 'channel_message') {
      final myId = await AppStorage.get('uid') as String?;
      if (myId != null && data['sender_id'] == myId) return;
    }
    if (_addaSuppressibleTypes.contains(type)) {
      final flag = await AppStorage.get('@is_in_adda') as String?;
      if (flag == 'true') return;
    }

    final title = data['title'] ?? message.notification?.title ?? 'WiTalk';
    final body  = data['body']  ?? message.notification?.body  ?? '';

    await _showIosLocalNotification(title: title, body: body, data: data);
  }

  static const _addaSuppressibleTypes = {
    'post', 'like', 'comment', 'comment_reply',
    'follow', 'social_interactions', 'adda',
    'topic_upvote', 'reply_upvote', 'profile_like',
    'profile_visit', 'referral', 'group_message', 'streak_reminder',
  };

  // ── iOS local notification display ────────────────────────────────────────

  Future<void> _showIosLocalNotification({
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final notifId = _notifIdForData(data);
    await _localNotifications.show(
      notifId, title, body,
      const NotificationDetails(iOS: iosDetails),
      payload: _encodePayload(data),
    );
  }

  // ── Tap handlers ──────────────────────────────────────────────────────────

  void _onNotificationTap(RemoteMessage message) {
    AppLogger.log('[FCM] Tapped (background): type=${message.data['type']}');
    _dispatch(_normalisePayload(message.data));
  }

  void _onLocalNotifTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      _dispatch(_decodePayload(payload));
    } catch (e) {
      AppLogger.error('[FCM] Error decoding tap payload', e);
    }
  }

  void _dispatch(Map<String, dynamic> data) {
    if (_onNotification != null) {
      _onNotification!(data);
    } else {
      _pendingNotification = data;
    }
  }

  // ── Token persistence ─────────────────────────────────────────────────────

  Future<void> _saveTokenLocally(String token) async {
    await AppStorage.set('@fcm_token', token);
  }

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
    if (Platform.isAndroid) return (await info.androidInfo).id;
    return (await info.iosInfo).identifierForVendor ?? '';
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

  Map<String, dynamic> _decodePayload(String payload) => Map.fromEntries(
    payload.split('&').map((kv) {
      final parts = kv.split('=');
      return MapEntry(
        Uri.decodeComponent(parts[0]),
        parts.length > 1 ? Uri.decodeComponent(parts.sublist(1).join('=')) : '',
      );
    }),
  );
}

final notificationService = NotificationService();
