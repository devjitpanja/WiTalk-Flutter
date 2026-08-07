import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'logger.dart';

const _methodChannel = MethodChannel('com.witalk/screenshot_prevent');
const _eventChannel  = EventChannel('com.witalk/screenshot_prevent_events');

StreamSubscription<dynamic>? _screenshotSub;

/// Enable or disable secure display mode.
///
/// Android : adds / clears FLAG_SECURE — OS blocks screenshots outright (black frame).
/// iOS     : moves Flutter view into a UITextField(isSecureTextEntry:true) protected
///           render layer — same GPay/banking-app technique — screenshots come out black.
///           Applied automatically at startup by the native plugin.
Future<void> setScreensecure({bool enable = true}) async {
  try {
    await _methodChannel.invokeMethod<void>('setSecure', {'enable': enable});
  } catch (e) {
    AppLogger.warn('[ScreenshotPrevention] setSecure failed: $e');
  }
}

/// Start listening for screenshot / screen-recording events.
///
/// Android : FLAG_SECURE blocks the action — no events emitted.
/// iOS     : fires "ScreenshotTaken" (content will be black due to secure layer)
///           and "ScreenRecordingStarted" when AirPlay/screen recording begins.
///
/// [onEvent] receives the event string so you can show [ScreenshotPrivacySheet].
void startScreenshotListener(void Function(String event) onEvent) {
  _screenshotSub?.cancel();
  if (Platform.isIOS) {
    _screenshotSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        AppLogger.log('[ScreenshotPrevention] Event: $event');
        onEvent(event as String? ?? 'ScreenshotTaken');
      },
      onError: (e) => AppLogger.warn('[ScreenshotPrevention] Stream error: $e'),
    );
  }
}

void stopScreenshotListener() {
  _screenshotSub?.cancel();
  _screenshotSub = null;
}
