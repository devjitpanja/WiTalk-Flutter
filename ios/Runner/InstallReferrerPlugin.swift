import Flutter
import Foundation

/// Flutter MethodChannel bridge for Install Referrer on iOS.
///
/// iOS has no Google Play Install Referrer API equivalent.
/// The Apple SKAdNetwork / StoreKit 2 AttributionToken provides attribution
/// data, but it uses a different model. For WiTalk's referral system:
/// - The referral code is passed as a URL query parameter in the App Clip
///   or universal link, which go_router / deep_link_handler already handles.
/// - This plugin returns empty data so Dart code doesn't throw.
///
/// Channel: com.witalk/install_referrer
/// Methods: getInstallReferrerInfo, isInstallReferrerAvailable
class InstallReferrerPlugin: NSObject, FlutterPlugin {

    static let channel = "com.witalk/install_referrer"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: InstallReferrerPlugin.channel,
            binaryMessenger: registrar.messenger()
        )
        let instance = InstallReferrerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getInstallReferrerInfo":
            // iOS does not support Play Install Referrer — return empty payload
            // so Dart code handles it gracefully (returns null referral code).
            result([
                "installReferrer": "",
                "referrerClickTimestampSeconds": 0.0,
                "installBeginTimestampSeconds": 0.0,
                "referrerClickTimestampServerSeconds": 0.0,
                "installBeginTimestampServerSeconds": 0.0,
                "installVersion": "",
                "googlePlayInstant": false,
            ])
        case "isInstallReferrerAvailable":
            // Not available on iOS
            result(false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
