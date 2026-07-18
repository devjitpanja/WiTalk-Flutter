import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../api/dio_client.dart';

const _oneSignalAppId = '86f427dd-6fc9-490a-93b9-0f69eeb5c5af';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      _showLocalNotification(
        title: event.notification.title ?? 'WiTalk',
        body: event.notification.body ?? '',
        payload: event.notification.notificationId,
      );
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      _handleNotificationData(data);
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

  Future<void> logout() async {
    await OneSignal.logout();
  }

  Future<void> _showLocalNotification({required String title, required String body, String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'witalk_main', 'WiTalk',
      channelDescription: 'WiTalk notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title, body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigation handled by app state
  }

  void _handleNotificationData(Map<String, dynamic>? data) {
    if (data == null) return;
    // Deep linking based on notification type
    final type = data['type'] as String?;
    final id = data['id'] as String?;
    if (type == 'message' && id != null) {
      // Navigate to chat — handled by app router
    }
  }
}

final notificationService = NotificationService();
