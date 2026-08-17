import Flutter
import UIKit

/**
 * Screenshot & screen-recording prevention for iOS.
 *
 * ── How GPay-style black screenshot works ────────────────────────────────────
 *
 * Apple does not expose FLAG_SECURE to third-party apps. However, iOS renders
 * UITextField with isSecureTextEntry = true inside a private, protected render
 * layer (CALayer backed by a restricted IOSurface). When a screenshot or screen
 * recording is taken, that render layer comes out BLACK — identical to
 * FLAG_SECURE on Android.
 *
 * Technique:
 *   1. Create a UITextField with isSecureTextEntry = true.
 *   2. Disable user interaction so it never actually receives input.
 *   3. Embed the Flutter view INSIDE the textField's subview layer — specifically
 *      inside textField.subviews.first, which is the protected CALayer container.
 *   4. The entire Flutter surface now lives inside the protected layer →
 *      screenshots and screen recordings produce a black frame.
 *
 * This is the exact technique used by GPay, Paytm, and many banking apps on iOS.
 * It requires no private APIs and passes App Store review.
 *
 * ── Screen recording detection ───────────────────────────────────────────────
 * UIScreen.main.isCaptured = true when AirPlay mirroring or screen recording
 * is active. We fire a "ScreenRecordingStarted" event when this turns on.
 *
 * ── Screenshot notification ──────────────────────────────────────────────────
 * With the UITextField technique active, screenshots are already black — the
 * notification is kept as an extra layer to show the ScreenshotPrivacySheet
 * (confirms to the user that the app blocked the capture).
 *
 * Channel:   com.witalk/screenshot_prevent
 * Method:    setSecure(enable: Bool)  — enables/disables the protected layer
 * Events:    "ScreenshotTaken", "ScreenRecordingStarted"
 */
class ScreenshotPreventPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let methodChannel = "com.witalk/screenshot_prevent"
    static let eventChannel  = "com.witalk/screenshot_prevent_events"

    private var eventSink: FlutterEventSink?
    private var captureObserver: NSObjectProtocol?
    private var recordingObserver: NSObjectProtocol?

    // The secure UITextField whose subview hosts the Flutter view
    private var secureField: UITextField?
    private var isSecureLayerActive = false

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ScreenshotPreventPlugin()

        let method = FlutterMethodChannel(
            name: methodChannel,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: method)

        let event = FlutterEventChannel(
            name: eventChannel,
            binaryMessenger: registrar.messenger()
        )
        event.setStreamHandler(instance)

        // Disabled: auto-applying the secure layer at startup reparents the Flutter
        // view into the UITextField's protected CALayer while the engine is rendering
        // its first frame → causes black screen after the native splash on iOS.
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        //     instance.applySecureLayer(enable: true)
        // }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "setSecure" {
            let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? true
            DispatchQueue.main.async { [weak self] in
                self?.applySecureLayer(enable: enable)
            }
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - UITextField secure layer technique

    /**
     * Moves the Flutter root view into a UITextField's protected render layer.
     *
     * When enable = true:
     *   - Creates a UITextField(isSecureTextEntry: true) sized to fill the window.
     *   - Moves the Flutter view into textField.subviews.first (the protected CALayer
     *     container that iOS renders as black in screenshots).
     *
     * When enable = false:
     *   - Moves the Flutter view back to the window as a normal subview.
     *   - Removes and deallocates the UITextField.
     */
    private func applySecureLayer(enable: Bool) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow }) else { return }

        guard let flutterView = window.subviews.first else { return }

        if enable && !isSecureLayerActive {
            let field = UITextField(frame: window.bounds)
            field.isSecureTextEntry = true
            field.isUserInteractionEnabled = false
            field.backgroundColor = .clear
            field.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            window.addSubview(field)

            // The first subview of a secure UITextField is the protected render container
            if let secureContainer = field.subviews.first {
                secureContainer.addSubview(flutterView)
                flutterView.frame = secureContainer.bounds
                flutterView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }

            secureField = field
            isSecureLayerActive = true

        } else if !enable && isSecureLayerActive {
            // Move Flutter view back to window before removing the field
            window.insertSubview(flutterView, at: 0)
            flutterView.frame = window.bounds
            flutterView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            secureField?.removeFromSuperview()
            secureField = nil
            isSecureLayerActive = false
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        // Screenshot notification — fires even when content is black (confirms block worked)
        captureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventSink?("ScreenshotTaken")
        }

        // Screen recording / AirPlay detection
        recordingObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if UIScreen.main.isCaptured {
                self?.eventSink?("ScreenRecordingStarted")
            }
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let obs = captureObserver {
            NotificationCenter.default.removeObserver(obs)
            captureObserver = nil
        }
        if let obs = recordingObserver {
            NotificationCenter.default.removeObserver(obs)
            recordingObserver = nil
        }
        eventSink = nil
        return nil
    }
}
