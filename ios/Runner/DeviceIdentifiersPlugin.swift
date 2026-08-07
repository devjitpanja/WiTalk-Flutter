import Flutter
import UIKit
import AdSupport
import AppTrackingTransparency

/**
 * Device identifier bridge for iOS.
 *
 * iOS does NOT have:
 *   - GAID → equivalent is IDFA (Identifier for Advertisers), requires ATT permission (iOS 14+)
 *   - Android ID → no direct equivalent; we use identifierForVendor (IDFV)
 *   - Widevine → no equivalent; iOS uses FairPlay DRM, which has no public device ID API
 *
 * Channel: com.witalk/device_identifiers
 *
 * Methods:
 *   getAdvertisingInfo() → Map {
 *       gaid: String (IDFA or "" if not authorized),
 *       isLimitAdTracking: Bool,
 *       isAdIdDeleted: Bool,
 *       idfv: String (identifierForVendor — stable per app-vendor pair)
 *   }
 *   getAndroidId()   → String (IDFV — closest iOS equivalent to ANDROID_ID)
 *   getWidevineInfo() → Map { securityLevel: "not_available_ios", deviceId: "" }
 */
class DeviceIdentifiersPlugin: NSObject, FlutterPlugin {

    static let channel = "com.witalk/device_identifiers"

    static func register(with registrar: FlutterPluginRegistrar) {
        let ch = FlutterMethodChannel(name: channel, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(DeviceIdentifiersPlugin(), channel: ch)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAdvertisingInfo":
            getAdvertisingInfo(result: result)
        case "getAndroidId":
            // IDFV is the iOS equivalent — stable for the same app across reinstalls
            // as long as no other apps from the same vendor are installed.
            result(UIDevice.current.identifierForVendor?.uuidString ?? "")
        case "getWidevineInfo":
            // FairPlay is iOS's DRM — no public device ID is exposed.
            result(["securityLevel": "not_available_ios", "deviceId": ""])
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - IDFA / ATT

    private func getAdvertisingInfo(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            switch status {
            case .authorized:
                let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                let isAllZeros = idfa == "00000000-0000-0000-0000-000000000000"
                result([
                    "gaid": isAllZeros ? "" : idfa,
                    "isLimitAdTracking": false,
                    "isAdIdDeleted": isAllZeros,
                    "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
                ])
            case .denied, .restricted:
                result([
                    "gaid": "",
                    "isLimitAdTracking": true,
                    "isAdIdDeleted": false,
                    "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
                ])
            case .notDetermined:
                // Request permission first, then return IDFA if granted.
                ATTrackingManager.requestTrackingAuthorization { authStatus in
                    DispatchQueue.main.async {
                        if authStatus == .authorized {
                            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                            let isAllZeros = idfa == "00000000-0000-0000-0000-000000000000"
                            result([
                                "gaid": isAllZeros ? "" : idfa,
                                "isLimitAdTracking": false,
                                "isAdIdDeleted": isAllZeros,
                                "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
                            ])
                        } else {
                            result([
                                "gaid": "",
                                "isLimitAdTracking": true,
                                "isAdIdDeleted": false,
                                "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
                            ])
                        }
                    }
                }
            @unknown default:
                result([
                    "gaid": "",
                    "isLimitAdTracking": true,
                    "isAdIdDeleted": false,
                    "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
                ])
            }
        } else {
            // iOS <14: no ATT required
            let manager = ASIdentifierManager.shared()
            let idfa = manager.advertisingIdentifier.uuidString
            let isLimit = !manager.isAdvertisingTrackingEnabled
            result([
                "gaid": isLimit ? "" : idfa,
                "isLimitAdTracking": isLimit,
                "isAdIdDeleted": false,
                "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
            ])
        }
    }
}
