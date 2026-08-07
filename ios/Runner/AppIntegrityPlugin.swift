import Flutter
import UIKit
import CryptoKit
import DeviceCheck

/**
 * iOS app integrity attestation.
 *
 * Strategy (tiered by OS availability):
 *   iOS 14+ : DCAppAttestService — Apple's recommended attestation service.
 *             Returns an attestation key ID + assertion token that the server can
 *             verify against Apple's attestation root CA.
 *   iOS 11-13: DCDevice.current.generateToken — returns a device token that can be
 *             sent to your server and verified via Apple's DeviceCheck API.
 *   iOS <11: Not available — returns { "error": "DeviceCheck not supported" }.
 *
 * Channel: com.witalk/app_integrity
 * Method:  requestIntegrityToken(nonce: String)
 *   → success: Map { "token": String, "nonce": String, "method": "app_attest" | "device_check" }
 *   → error:   Map { "error": String }
 *
 * The "method" key tells the server which verification path to use.
 * The server must implement both:
 *   - App Attest: https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity
 *   - DeviceCheck: https://developer.apple.com/documentation/devicecheck
 */
class AppIntegrityPlugin: NSObject, FlutterPlugin {

    static let channel = "com.witalk/app_integrity"

    static func register(with registrar: FlutterPluginRegistrar) {
        let ch = FlutterMethodChannel(name: channel, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(AppIntegrityPlugin(), channel: ch)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "requestIntegrityToken" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args = call.arguments as? [String: Any],
              let nonce = args["nonce"] as? String else {
            result(["error": "Nonce is required"])
            return
        }

        if #available(iOS 14.0, *) {
            requestAppAttest(nonce: nonce, result: result)
        } else if DCDevice.current.isSupported {
            requestDeviceCheck(nonce: nonce, result: result)
        } else {
            result(["error": "DeviceCheck not supported on this device"])
        }
    }

    // MARK: - App Attest (iOS 14+)

    @available(iOS 14.0, *)
    private func requestAppAttest(nonce: String, result: @escaping FlutterResult) {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            // Simulator or unsupported hardware — fall through to DeviceCheck
            if DCDevice.current.isSupported {
                requestDeviceCheck(nonce: nonce, result: result)
            } else {
                result(["error": "App Attest not supported on this device"])
            }
            return
        }

        // Hash the nonce with SHA-256 as required by App Attest
        guard let nonceData = nonce.data(using: .utf8) else {
            result(["error": "Invalid nonce encoding"])
            return
        }
        let clientDataHash = Data(SHA256.hash(data: nonceData))

        // Generate a new attestation key
        service.generateKey { keyId, error in
            if let error = error {
                result(["error": "Key generation failed: \(error.localizedDescription)"])
                return
            }
            guard let keyId = keyId else {
                result(["error": "Key generation returned nil"])
                return
            }

            // Attest the key against the nonce hash
            service.attestKey(keyId, clientDataHash: clientDataHash) { attestObj, error in
                if let error = error {
                    result(["error": "Attestation failed: \(error.localizedDescription)"])
                    return
                }
                guard let attestObj = attestObj else {
                    result(["error": "Attestation returned nil"])
                    return
                }
                let token = attestObj.base64EncodedString()
                result(["token": token, "nonce": nonce, "keyId": keyId, "method": "app_attest"])
            }
        }
    }

    // MARK: - DeviceCheck (iOS 11-13 fallback)

    private func requestDeviceCheck(nonce: String, result: @escaping FlutterResult) {
        DCDevice.current.generateToken { token, error in
            if let error = error {
                result(["error": "DeviceCheck failed: \(error.localizedDescription)"])
                return
            }
            guard let token = token else {
                result(["error": "DeviceCheck returned nil token"])
                return
            }
            result(["token": token.base64EncodedString(), "nonce": nonce, "method": "device_check"])
        }
    }
}
