import Flutter
import Foundation
import Network

/// Flutter MethodChannel bridge for VPN / simulator / Frida detection on iOS.
///
/// Channel: com.witalk/vpn_detector
/// Methods: isVpnActive, isAdvancedEmulator, isFridaDetected
class VpnDetectorPlugin: NSObject, FlutterPlugin {

    static let channel = "com.witalk/vpn_detector"

    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: VpnDetectorPlugin.channel,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(VpnDetectorPlugin(), channel: methodChannel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isVpnActive":
            result(isVpnActive())
        case "isAdvancedEmulator":
            result(isSimulator())
        case "isFridaDetected":
            result(isFridaDetected())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── VPN detection ──────────────────────────────────────────────────────

    private func isVpnActive() -> Bool {
        // Inspect active network interface names via getifaddrs
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            let name = String(cString: ptr.pointee.ifa_name)
            // utun* appears for VPNs; ppp* for PPP-based VPNs; ipsec* for IPSec
            if name.hasPrefix("utun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") || name.hasPrefix("tun") {
                return true
            }
            cursor = ptr.pointee.ifa_next
        }
        return false
    }

    // ── Simulator detection ─────────────────────────────────────────────────

    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // ── Frida / hooking detection ──────────────────────────────────────────

    private func isFridaDetected() -> Bool {
        // 1. Frida default server port 27042
        if isTcpPortOpen(port: 27042) { return true }

        // 2. Known Frida file artifacts
        let fridaPaths = [
            "/usr/lib/frida/frida-agent.dylib",
            "/usr/share/frida/frida-agent.dylib",
            "/tmp/frida-agent.dylib",
        ]
        for path in fridaPaths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }

        // 3. Scan loaded dylibs for Frida / Cycript signatures
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let nameCStr = _dyld_get_image_name(i) {
                let name = String(cString: nameCStr).lowercased()
                if name.contains("frida") || name.contains("cynject") || name.contains("libcycript") {
                    return true
                }
            }
        }

        return false
    }

    private func isTcpPortOpen(port: UInt16) -> Bool {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd >= 0 else { return false }
        defer { close(sockfd) }

        // 150 ms timeout
        var tv = timeval(tv_sec: 0, tv_usec: 150_000)
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        return withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sockfd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }
}
