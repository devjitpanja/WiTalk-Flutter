# WiTalk Security Implementation

## Overview

All security features are implemented for both Android and iOS in the same Flutter codebase. Where platforms differ, both are handled with appropriate fallbacks. This file documents what was implemented, why it works, iOS-specific limitations, and what must be done after Apple Developer Console access is obtained.

---

## 1. Screenshot & Screen Recording Prevention

### Android
- **Mechanism:** `FLAG_SECURE` applied to the Activity Window via `ScreenshotPreventPlugin.kt`.
- **Effect:** The OS blocks screenshots and screen recordings at the system level. Any attempt produces a completely black frame. No user notification needed — the OS handles it silently.
- **Applied:** Automatically on app launch. Can be toggled via `setSecure(enable)` (e.g. disabled in the screenshot-sharing feature of AddaShareCard).

### iOS — GPay Technique (implemented)
- **Mechanism:** `UITextField(isSecureTextEntry: true)` secure render layer trick.
- **Why it works:** iOS renders secure text fields inside a private, protected CALayer backed by a restricted `IOSurface`. Apple prevents this surface from being captured by screenshots or screen recordings. By moving the Flutter root view *inside* `textField.subviews.first` (the protected container), the entire app surface inherits that protection.
- **Effect:** Screenshots and screen recordings produce a completely black frame — identical to Android `FLAG_SECURE`. This is the same technique used by GPay, Paytm, PhonePe, and all major banking apps on iOS.
- **No private APIs used.** Passes App Store review.
- **Applied:** Automatically on app launch via `ScreenshotPreventPlugin.swift`.

### iOS — Additional Detection Layer
Even with the black-frame technique active, `UIApplication.userDidTakeScreenshotNotification` fires when a screenshot is attempted. The Dart layer receives a `"ScreenshotTaken"` event and shows `ScreenshotPrivacySheet` — confirming to the user that the attempt was blocked.

Screen recording is detected via `UIScreen.capturedDidChangeNotification` → fires `"ScreenRecordingStarted"` event.

### Files
- `android/app/src/main/kotlin/com/witalk/ScreenshotPreventPlugin.kt`
- `ios/Runner/ScreenshotPreventPlugin.swift`
- `lib/utils/screenshot_prevention.dart`
- `lib/widgets/common/screenshot_privacy_sheet.dart`

---

## 2. App Integrity Verification

### Android — Play Integrity API
- Requests an `integrityToken` + `nonce` via `AppIntegrityPlugin.kt`.
- Token + nonce sent in `POST /v1/user/create` payload.
- Server verifies the token against Google's Play Integrity API to confirm:
  - App was installed from the Play Store (not sideloaded/modified).
  - Device passes basic Android integrity.
  - No known malware active on the device.

### iOS — App Attest + DeviceCheck

> **⚠️ REQUIRES APPLE DEVELOPER CONSOLE — See Section 9 below.**

- **iOS 14+:** `DCAppAttestService` — Apple's recommended attestation service. Returns a CBOR attestation object that proves the app binary has not been tampered with.
- **iOS 11-13:** `DCDevice.generateToken` — DeviceCheck fallback. Proves the device is a real Apple device.
- **Implementation:** `AppIntegrityPlugin.swift` handles both paths automatically.
- **Server must implement both verification paths** — App Attest via Apple's attestation root CA, DeviceCheck via `https://api.devicecheck.apple.com/v1/validate_device_token`.

### Files
- `android/app/src/main/kotlin/com/witalk/AppIntegrityPlugin.kt`
- `ios/Runner/AppIntegrityPlugin.swift`
- `lib/utils/app_integrity.dart`

---

## 3. Device Ban + Identifier Ban

### Both Platforms
- **Pre-login device ban check** runs before Google Sign-In via `BanCheckService.checkAllDeviceBans()`.
- Results cached for 2 minutes so repeated taps are instant.
- Two parallel checks:
  - `POST /v1/user/check-device-ban` — device unique ID, brand, model.
  - `POST /v1/user/check-identifier-ban` — advertising ID + DRM device ID.

### Platform differences
| Identifier | Android | iOS |
|---|---|---|
| Device unique ID | `ANDROID_ID` | `identifierForVendor` (IDFV) |
| Advertising ID | GAID via Google Play Services | IDFA via `ASIdentifierManager` (requires ATT permission) |
| DRM device ID | Widevine `PROPERTY_DEVICE_UNIQUE_ID` | `not_available_ios` — FairPlay has no public device ID |
| Install referrer | Google Play Install Referrer API | Not available — iOS uses deep links |

### Files
- `android/app/src/main/kotlin/com/witalk/DeviceIdentifiersPlugin.kt`
- `ios/Runner/DeviceIdentifiersPlugin.swift`
- `lib/utils/device_identifiers.dart`
- `lib/services/ban_check_service.dart`

---

## 4. ISP / Network Block Check

- On app open, `prefetchAuthSecurityData()` fires in the background.
- Fetches `GET /v1/auth/ip-lookup` and `GET /v1/auth/blocked-isps` in parallel.
- At sign-in time, login is blocked if:
  - `user_type == 'hosting'` or `'datacenter'` (VPN / datacenter IP).
  - User's ASN or ISP name matches any entry in the blocked ISP list.
- Works identically on Android and iOS — no platform-specific code.

### API key
- `findipApiToken` moved from hardcoded source to `AppConfig.findipApiToken`.
- For production, move this to `--dart-define` or Firebase Remote Config.

---

## 5. Security Profile Telemetry

- `collectAndSendSecurityProfile()` sends device + security flag snapshot to `POST /v1/user/device-security-profile`.
- Called fire-and-forget (never blocks the user).
- Triggers: `app_open`, `foreground`, `login`.
- Checks: VPN active, advanced emulator, Frida/Xposed hooking.
- Platform fields:

| Field | Android | iOS |
|---|---|---|
| `isRooted` / `isJailbroken` | JailMonkey (planned — see §9) | JailMonkey (planned) |
| `isVpn` | `ConnectivityManager.TRANSPORT_VPN` | `getifaddrs` interface scan |
| `isAdvancedEmulator` | 9-layer detection (files, build props, packages, sensors, storage) | `#if targetEnvironment(simulator)` |
| `isFridaDetected` | `/proc/self/maps` + port 27042 + Xposed files | Port 27042 + dylib scan + file paths |
| `securityPatch` | `Build.VERSION.securityPatch` | Not applicable |
| `widevineSecurityLevel` | `L1` / `L2` / `L3` | `not_available_ios` |

---

## 6. Offline Network Pre-Check

- `connectivity_plus` listener tracks network state in real time.
- `_isOffline` flag set synchronously — no `await` in the hot path.
- Dio `onRequest` interceptor rejects requests immediately with `NETWORK_ERROR: Device is offline` if offline.
- Mirrors RN `NetInfo` pre-check in `axios.js`.

---

## 7. Ghost Mode (Location Privacy)

- `GhostModeService` — `enableGhostMode(uid, duration)`, `disableGhostMode(uid)`, `getStatus(uid)`.
- Duration options: 3 hours, 24 hours, indefinite.
- UI: ghost button (top-right) in `NearbyPeopleScreen`. Tapping shows `_GhostModeSheet` duration picker. Active state shows "Not sharing location" banner.
- Works identically on Android and iOS.

---

## 8. Report Screen

- Categories fetched dynamically from `GET /v1/report/categories` with hardcoded fallback.
- `409 Conflict` (already reported) handled gracefully — shows toast, goes back.
- 10-second client-side rate limit between submissions.
- `description` field required when category is `other`.

---

## 9. ⚠️ TODO: Requires Apple Developer Console

The following cannot be activated without an Apple Developer Account. All code is already written and will compile — these are **activation/configuration steps only**.

### 9.1 App Attest (DCAppAttestService)

**What it does:** Proves to your server that the app binary is the genuine App Store build — prevents modified/cracked APKs.

**Steps:**
1. In Apple Developer Console → **Certificates, IDs & Profiles** → select your App ID.
2. Under **Capabilities**, enable **App Attest**.
3. In Xcode → target → **Signing & Capabilities** → add **App Attest** capability.
4. Server-side: implement the two-step attestation flow:
   - Verify attestation object against Apple's root CA: `https://app-attest.apple.com`
   - Store the public key associated with the `keyId` returned by `AppIntegrityPlugin.swift`.
   - For subsequent assertions, verify using the stored public key.
   - Reference: https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity

### 9.2 DeviceCheck (iOS 11-13 fallback)

**Steps:**
1. In Apple Developer Console → **Keys** → create a new key with **DeviceCheck** enabled. Download the `.p8` file.
2. Note the Key ID and Team ID.
3. Server-side: verify device tokens at:
   - Sandbox: `https://api.development.devicecheck.apple.com/v1/validate_device_token`
   - Production: `https://api.devicecheck.apple.com/v1/validate_device_token`
   - Auth: JWT signed with your `.p8` key using ES256.
   - Reference: https://developer.apple.com/documentation/devicecheck/accessing_and_modifying_per-device_data

### 9.3 NSUserTrackingUsageDescription (IDFA / ATT)

**What it does:** Required by iOS 14+ to request permission to read IDFA (advertising ID). Without this, `getAdvertisingInfo()` always returns empty GAID on iOS.

**Steps:**
1. Open `ios/Runner/Info.plist`.
2. Add:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>WiTalk uses this to help prevent fake accounts and protect the community from banned users.</string>
```
3. The ATT permission dialog will appear once per install. If denied, IDFV is used as fallback (already handled in `DeviceIdentifiersPlugin.swift`).

### 9.4 Root / Jailbreak Detection (JailMonkey)

**Current state:** `security_profile.dart` sends VPN/emulator/Frida checks but does NOT currently include root/jailbreak detection — the `jailbreakDetected` field in the server payload will always be null until this is added.

**Steps:**
1. Add `jail_monkey: ^2.0.1` to `pubspec.yaml`.
2. In `security_profile.dart`, replace the placeholder comment with:
```dart
import 'package:jail_monkey/jail_monkey.dart';
// inside collectAndSendSecurityProfile():
final isJailbroken = await JailMonkey.isJailBroken();
final hookDetected = await JailMonkey.hookDetected();
final isMockLocation = await JailMonkey.isMockLocation();
final isDebuggable = JailMonkey.isDebuggable;
```
3. Add to payload: `isRooted`, `hookDetected`, `isMockLocation`, `isDebuggable`.

**Note:** JailMonkey checks both Android (root detection) and iOS (jailbreak detection) in the same API.

### 9.5 Push Notification Entitlement

Already configured via OneSignal, but the APNs entitlement must be activated:
1. Apple Developer Console → App ID → enable **Push Notifications**.
2. Create APNs Auth Key or certificate and upload to OneSignal.

---

## 10. Security Architecture Summary

```
Sign-in flow (both platforms)
  │
  ├─ Device ban check (device ID + advertising ID + DRM ID)
  │     └─ Blocks login before Google Sign-In even starts
  │
  ├─ ISP / network check (IP lookup + blocked ISP list)
  │     └─ Blocks VPN/datacenter IPs and banned ISPs
  │
  ├─ Google Sign-In + Firebase credential
  │
  ├─ App integrity token (Play Integrity / App Attest)
  │     └─ Attached to POST /v1/user/create
  │
  └─ Security profile (fire-and-forget)
        └─ VPN, emulator, Frida, device telemetry → server

Runtime (every foreground)
  ├─ Periodic ban check (every 5 min) → handleBannedUser() if banned
  ├─ Security profile resend (reason: 'foreground')
  └─ Offline network monitor (rejects requests instantly if offline)

Screenshot prevention
  ├─ Android: FLAG_SECURE (OS blocks capture → black frame)
  └─ iOS:     UITextField secure layer (GPay technique → black frame)
              + UIApplication.userDidTakeScreenshotNotification → ScreenshotPrivacySheet
              + UIScreen.capturedDidChangeNotification → ScreenRecordingStarted event
```

---

## 11. Keys & Secrets

| Key | Location | Status |
|---|---|---|
| `findipApiToken` | `AppConfig.findipApiToken` | Move to `--dart-define` or Firebase Remote Config before public launch |
| Google Maps API Key | `AppConfig.googleMapsApiKey` | Restrict to bundle ID + SHA in Google Cloud Console |
| Google Web Client ID | `AppConfig.googleWebClientId` | Restrict to bundle ID in Google Cloud Console |
| OneSignal App ID | `AppConfig.oneSignalAppId` | Public ID — safe in source |
| Apple DeviceCheck Key (`.p8`) | **Not in repo** | Store server-side only — never in the app |
| Firebase `google-services.json` | `android/app/` | Restrict API keys in Firebase console |
| Firebase `GoogleService-Info.plist` | `ios/Runner/` | Restrict API keys in Firebase console |
