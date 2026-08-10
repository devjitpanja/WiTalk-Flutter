import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase — must be called before GeneratedPluginRegistrant so FirebaseMessaging
    // is available when the flutter firebase_messaging plugin initialises.
    FirebaseApp.configure()

    // Register Flutter plugins (firebase_messaging, flutter_local_notifications, etc.)
    GeneratedPluginRegistrant.register(with: self)

    // Custom native plugins
    VpnDetectorPlugin.register(with: registrar(forPlugin: "VpnDetectorPlugin")!)
    InstallReferrerPlugin.register(with: registrar(forPlugin: "InstallReferrerPlugin")!)
    AudioRoomServicePlugin.register(with: registrar(forPlugin: "AudioRoomServicePlugin")!)
    ScreenshotPreventPlugin.register(with: registrar(forPlugin: "ScreenshotPreventPlugin")!)
    AppIntegrityPlugin.register(with: registrar(forPlugin: "AppIntegrityPlugin")!)
    DeviceIdentifiersPlugin.register(with: registrar(forPlugin: "DeviceIdentifiersPlugin")!)

    // ── FCM / APNs wiring ─────────────────────────────────────────────────
    // Forward APNs tokens to Firebase so it can map APNs ↔ FCM tokens.
    Messaging.messaging().delegate = self

    // Required for foreground notification presentation (flutter_local_notifications
    // sets itself as delegate too; FlutterAppDelegate chains both).
    UNUserNotificationCenter.current().delegate = self

    // Register for remote notifications — triggers APNs token generation.
    // The Dart firebase_messaging plugin calls requestPermission(); this
    // call just ensures the token is issued regardless of permission status.
    application.registerForRemoteNotifications()
    // ─────────────────────────────────────────────────────────────────────

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── APNs token → Firebase ─────────────────────────────────────────────────

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[FCM] APNs registration failed: \(error.localizedDescription)")
  }

  // ── Foreground presentation ───────────────────────────────────────────────
  // Allow banner + sound + badge while app is in foreground.
  // super delegates to FlutterAppDelegate which forwards to flutter_local_notifications.

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
}

// ── FirebaseMessagingDelegate ─────────────────────────────────────────────────

extension AppDelegate: MessagingDelegate {
  // Called by Firebase when the FCM token is created or refreshed.
  // The Dart onTokenRefresh stream handles the upload; this is a safety-net log.
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let token = fcmToken else { return }
    print("[FCM] iOS token refreshed: \(token.prefix(30))...")
  }
}
