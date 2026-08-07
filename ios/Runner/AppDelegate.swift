import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    VpnDetectorPlugin.register(with: registrar(forPlugin: "VpnDetectorPlugin")!)
    InstallReferrerPlugin.register(with: registrar(forPlugin: "InstallReferrerPlugin")!)
    AudioRoomServicePlugin.register(with: registrar(forPlugin: "AudioRoomServicePlugin")!)
    ScreenshotPreventPlugin.register(with: registrar(forPlugin: "ScreenshotPreventPlugin")!)
    AppIntegrityPlugin.register(with: registrar(forPlugin: "AppIntegrityPlugin")!)
    DeviceIdentifiersPlugin.register(with: registrar(forPlugin: "DeviceIdentifiersPlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
