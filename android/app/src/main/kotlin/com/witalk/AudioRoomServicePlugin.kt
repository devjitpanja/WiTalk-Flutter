package com.witalk

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter bridge for the AudioRoom foreground service.
 *
 * MethodChannel  → com.witalk/audio_room_service
 *   startService(roomName, isHost, isInSeat, isMuted)
 *   stopService()
 *   updateService(roomName, isHost, isInSeat, isMuted)
 *
 * EventChannel   → com.witalk/audio_room_events
 *   Emits String events:
 *     "micToggle"   – user tapped Mute/Unmute in the notification
 *     "leaveRoom"   – user tapped Leave in the notification
 */
class AudioRoomServicePlugin(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.witalk/audio_room_service"
        const val EVENT_CHANNEL = "com.witalk/audio_room_events"

        // Singleton event sink shared with the service (static so service can reach it)
        private var eventSink: EventChannel.EventSink? = null

        fun sendEvent(action: String) {
            val event = when (action) {
                AudioRoomForegroundService.ACTION_MIC_TOGGLE -> "micToggle"
                AudioRoomForegroundService.ACTION_LEAVE_ROOM -> "leaveRoom"
                else -> action
            }
            // Must run on main thread
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                eventSink?.success(event)
            }
        }
    }

    // ── EventChannel.StreamHandler ────────────────────────────────────────────

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ── MethodChannel.MethodCallHandler ───────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startService" -> {
                if (!hasMicPermission()) {
                    result.error("PERMISSION_DENIED", "RECORD_AUDIO permission not granted", null)
                    return
                }
                val intent = buildServiceIntent(AudioRoomForegroundService.ACTION_START, call)
                startForegroundServiceSafely(intent)
                result.success(null)
            }
            "stopService" -> {
                val intent = Intent(context, AudioRoomForegroundService::class.java).apply {
                    action = AudioRoomForegroundService.ACTION_STOP
                }
                context.startService(intent)
                result.success(null)
            }
            "updateService" -> {
                val intent = buildServiceIntent(AudioRoomForegroundService.ACTION_UPDATE, call)
                if (isServiceRunning()) {
                    context.startService(intent)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun buildServiceIntent(action: String, call: MethodCall): Intent =
        Intent(context, AudioRoomForegroundService::class.java).apply {
            this.action = action
            putExtra(AudioRoomForegroundService.EXTRA_ROOM_NAME,
                call.argument<String>("roomName") ?: "WiTalk Adda")
            putExtra(AudioRoomForegroundService.EXTRA_IS_HOST,
                call.argument<Boolean>("isHost") ?: false)
            putExtra(AudioRoomForegroundService.EXTRA_IS_IN_SEAT,
                call.argument<Boolean>("isInSeat") ?: false)
            putExtra(AudioRoomForegroundService.EXTRA_IS_MUTED,
                call.argument<Boolean>("isMuted") ?: false)
        }

    private fun startForegroundServiceSafely(intent: Intent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException on Android 12+ when app is in background
            // Log and ignore — the service is best-effort
            e.printStackTrace()
        }
    }

    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED

    @Suppress("DEPRECATION")
    private fun isServiceRunning(): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        return am.getRunningServices(Int.MAX_VALUE)
            .any { it.service.className == AudioRoomForegroundService::class.java.name }
    }
}
