import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // VPN / emulator / Frida detection
    let vpnChannel = FlutterMethodChannel(
      name: VpnDetectorPlugin.channel,
      binaryMessenger: engineBridge.binaryMessenger
    )
    vpnChannel.setMethodCallHandler(VpnDetectorPlugin().handle(_:result:))

    // Install Referrer (iOS returns empty — referral via deep link instead)
    let referrerChannel = FlutterMethodChannel(
      name: InstallReferrerPlugin.channel,
      binaryMessenger: engineBridge.binaryMessenger
    )
    referrerChannel.setMethodCallHandler(InstallReferrerPlugin().handle(_:result:))
  }
}
