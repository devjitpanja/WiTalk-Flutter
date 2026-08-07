import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../api/dio_client.dart';
import '../utils/logger.dart';
import 'deep_link_service.dart';

const _oneSignalAppId = '86f427dd-6fc9-490a-93b9-0f69eeb5c5af';

// ---------------------------------------------------------------------------
// Notification data arrives in two shapes from OneSignal:
//   • foreground / warm: additionalData is the full payload map
//   • cold start / kill:  additionalData may be flat or nested under "data"
// handleNotificationNavigation normalises both shapes.
// ---------------------------------------------------------------------------

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Pending notification stored during cold start (navigation not yet ready).
  Map<String, dynamic>? _pendingNotification;

  // Context provider — set from main.dart once the router is mounted.
  // Using a thunk avoids storing a stale BuildContext.
  void Function(Map<String, dynamic>)? _onNotification;

  /// Called from main.dart after the router is ready.
  /// [handler] receives the notification payload and performs navigation.
  void setNavigationHandler(void Function(Map<String, dynamic>) handler) {
    _onNotification = handler;
    // Flush any notification that arrived before navigation was ready
    if (_pendingNotification != null) {
      final pending = _pendingNotification!;
      _pendingNotification = null;
      handler(pending);
    }
  }

  Future<void> initialize() async {
    // ── Local notifications (shown in foreground) ──────────────────────────
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // ── OneSignal ──────────────────────────────────────────────────────────
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    // Foreground: suppress system banner and show a local notification instead
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      _showLocalNotification(
        title: event.notification.title ?? 'WiTalk',
        body: event.notification.body ?? '',
        payload: event.notification.additionalData != null
            ? _encodePayload(event.notification.additionalData!)
            : event.notification.notificationId,
      );
    });

    // Tap on notification (both warm start and cold start after the widget
    // tree is ready — cold-start before ready is handled via _pendingNotification).
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData ?? {};
      AppLogger.log('[Notifications] Tapped: type=${data['type'] ?? data['notification_type']}');
      _dispatchNotification(Map<String, dynamic>.from(data));
    });
  }

  Future<void> setExternalUserId(String userId) async {
    await OneSignal.login(userId);
    try {
      final token = OneSignal.User.pushSubscription.id;
      if (token != null) {
        final deviceId = await _getDeviceId();
        await dioClient.post('/v1/fcm/token/register', data: {
          'token': token,
          'deviceId': deviceId,
          'deviceType': Platform.isAndroid ? 'android' : 'ios',
          'userId': userId,
          'platform': 'onesignal',
        });
      }
    } catch (_) {}
  }

  Future<void> logout() async => OneSignal.logout();

  // ── Private helpers ──────────────────────────────────────────────────────

  void _dispatchNotification(Map<String, dynamic> data) {
    if (_onNotification != null) {
      _onNotification!(data);
    } else {
      // Navigation not yet ready — queue it
      _pendingNotification = data;
      AppLogger.log('[Notifications] Navigation not ready, queuing notification');
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    // Local notifications show the same payload we encoded earlier.
    // For now local taps do not navigate — the OneSignal click listener
    // handles the authoritative navigation path.
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'witalk_main',
      'WiTalk',
      channelDescription: 'WiTalk notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return android.id;
    } else {
      final ios = await info.iosInfo;
      return ios.identifierForVendor ?? '';
    }
  }

  String _encodePayload(Map<String, dynamic> data) {
    try {
      return data.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
    } catch (_) {
      return '';
    }
  }
}

final notificationService = NotificationService();
