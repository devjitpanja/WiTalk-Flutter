package com.witalk

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Screenshot prevention plugin.
 *
 * Android: FLAG_SECURE on the Window — prevents screenshots and screen recording at the OS
 * level. A screenshot attempt silently produces a blank/black image.
 *
 * EventChannel fires nothing on Android (the OS blocks the capture outright).
 * On iOS we cannot block captures, so the iOS plugin fires events instead and the
 * Dart layer shows a ScreenshotPrivacySheet bottom sheet.
 *
 * Methods:
 *   setSecure(enable: Bool) — add or clear FLAG_SECURE
 */
class ScreenshotPreventPlugin(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.witalk/screenshot_prevent"
        const val EVENT_CHANNEL  = "com.witalk/screenshot_prevent_events"
    }

    init {
        // Secure by default
        applySecureFlag(true)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setSecure" -> {
                val enable = call.argument<Boolean>("enable") ?: true
                applySecureFlag(enable)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun applySecureFlag(enable: Boolean) {
        activity.runOnUiThread {
            if (enable) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
    override fun onCancel(arguments: Any?) {}
}
