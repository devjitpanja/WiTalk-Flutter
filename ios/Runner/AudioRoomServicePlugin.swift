import Flutter
import UIKit
import AVFoundation
import CallKit
import UserNotifications

/**
 iOS bridge for WiTalk Audio Room background support.

 MethodChannel  → com.witalk/audio_room_service
   startService(roomName, isHost, isInSeat, isMuted)
   stopService()
   updateService(roomName, isHost, isInSeat, isMuted)

 EventChannel   → com.witalk/audio_room_events
   "micToggle"  – from CallKit / notification action
   "leaveRoom"  – from CallKit end-call button

 iOS background strategy:
  1. AVAudioSession with .playAndRecord + .allowBluetooth keeps audio alive in background
  2. UIBackgroundModes: audio declared in Info.plist
  3. CXCallController / CXProvider shows a CallKit call UI (same as WhatsApp / FaceTime)
     – Tap mic button   → emits "micToggle" to Flutter
     – Tap end button   → emits "leaveRoom" to Flutter
  4. UNUserNotificationCenter request for notification permission at start
 */
@objc class AudioRoomServicePlugin: NSObject {

    static let methodChannelName = "com.witalk/audio_room_service"
    static let eventChannelName  = "com.witalk/audio_room_events"

    private var eventSink: FlutterEventSink?
    private var callProvider: CXProvider?
    private var callController: CXCallController?
    private var activeCallUUID: UUID?
    private var roomName: String = "WiTalk Adda"
    private var isHost: Bool = false
    private var isInSeat: Bool = false
    private var isMuted: Bool = false

    // MARK: – Registration

    @objc static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = AudioRoomServicePlugin()

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(plugin, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(plugin)
    }

    // MARK: – CallKit setup

    private func setupCallKit() {
        let config = CXProviderConfiguration()
        config.localizedName = "WiTalk Adda"
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic]
        if let icon = UIImage(named: "AppIcon") {
            config.iconTemplateImageData = icon.pngData()
        }
        callProvider = CXProvider(configuration: config)
        callProvider?.setDelegate(self, queue: .main)
        callController = CXCallController()
    }

    // MARK: – AVAudioSession

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioRoomServicePlugin] AVAudioSession activate error: \(error)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false,
                options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioRoomServicePlugin] AVAudioSession deactivate error: \(error)")
        }
    }

    // MARK: – Notification permission

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    // MARK: – CallKit call lifecycle

    private func startCall(roomName: String) {
        guard callProvider != nil else { return }
        let uuid = UUID()
        activeCallUUID = uuid
        let handle = CXHandle(type: .generic, value: roomName)
        let startAction = CXStartCallAction(call: uuid, handle: handle)
        startAction.isVideo = false
        let transaction = CXTransaction(action: startAction)
        callController?.request(transaction) { [weak self] error in
            if let error = error {
                print("[AudioRoomServicePlugin] CallKit start error: \(error)")
                // Fallback: report incoming to at least show the call UI
                self?.reportOutgoingCallConnected(uuid: uuid)
            } else {
                self?.reportOutgoingCallConnected(uuid: uuid)
            }
        }
    }

    private func reportOutgoingCallConnected(uuid: UUID) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: roomName)
        update.localizedCallerName = roomName
        update.hasVideo = false
        callProvider?.reportCall(with: uuid, updated: update)
        callProvider?.reportOutgoingCall(with: uuid, connectedAt: Date())
    }

    private func endCall() {
        guard let uuid = activeCallUUID else { return }
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController?.request(transaction) { _ in }
        activeCallUUID = nil
    }

    private func updateCallMute(_ muted: Bool) {
        guard let uuid = activeCallUUID else { return }
        let muteAction = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: muteAction)
        callController?.request(transaction) { _ in }
    }
}

// MARK: – FlutterMethodCallDelegate

extension AudioRoomServicePlugin: FlutterMethodCallDelegate {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "startService":
            roomName  = args?["roomName"]  as? String ?? "WiTalk Adda"
            isHost    = args?["isHost"]    as? Bool   ?? false
            isInSeat  = args?["isInSeat"]  as? Bool   ?? false
            isMuted   = args?["isMuted"]   as? Bool   ?? false
            requestNotificationPermission()
            setupCallKit()
            activateAudioSession()
            startCall(roomName: roomName)
            result(nil)

        case "stopService":
            endCall()
            deactivateAudioSession()
            result(nil)

        case "updateService":
            let newMuted = args?["isMuted"] as? Bool ?? isMuted
            let newInSeat = args?["isInSeat"] as? Bool ?? isInSeat
            if newMuted != isMuted {
                isMuted = newMuted
                updateCallMute(isMuted)
            }
            isInSeat = newInSeat
            isHost   = args?["isHost"]    as? Bool ?? isHost
            roomName = args?["roomName"]  as? String ?? roomName
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: – FlutterStreamHandler

extension AudioRoomServicePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: – CXProviderDelegate

extension AudioRoomServicePlugin: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        deactivateAudioSession()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        activateAudioSession()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // User tapped end-call in CallKit UI → signal Flutter
        eventSink?("leaveRoom")
        deactivateAudioSession()
        activeCallUUID = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        // User toggled mute in CallKit UI → signal Flutter
        isMuted = action.isMuted
        eventSink?("micToggle")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // CallKit has taken ownership of the audio session — nothing extra needed
        // livekit_client manages its own audio routing from here
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // Called when call ends and CallKit releases the audio session
    }
}
