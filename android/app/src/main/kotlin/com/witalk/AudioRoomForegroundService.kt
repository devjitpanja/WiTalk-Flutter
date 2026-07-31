package com.witalk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat

class AudioRoomForegroundService : Service() {

    companion object {
        const val ACTION_START = "com.witalk.AUDIO_ROOM_START"
        const val ACTION_STOP = "com.witalk.AUDIO_ROOM_STOP"
        const val ACTION_UPDATE = "com.witalk.AUDIO_ROOM_UPDATE"

        const val EXTRA_ROOM_NAME = "room_name"
        const val EXTRA_IS_HOST = "is_host"
        const val EXTRA_IS_IN_SEAT = "is_in_seat"
        const val EXTRA_IS_MUTED = "is_muted"

        // These intent actions are intercepted by AudioRoomServicePlugin and forwarded to Flutter
        const val ACTION_MIC_TOGGLE = "com.witalk.AUDIO_ROOM_MIC_TOGGLE"
        const val ACTION_LEAVE_ROOM = "com.witalk.AUDIO_ROOM_LEAVE"

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "audio_room_channel"
        private const val CHANNEL_NAME = "WiTalk Audio Room"
    }

    private var roomName: String = "WiTalk Adda"
    private var isHost: Boolean = false
    private var isInSeat: Boolean = false
    private var isMuted: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                roomName = intent.getStringExtra(EXTRA_ROOM_NAME) ?: "WiTalk Adda"
                isHost = intent.getBooleanExtra(EXTRA_IS_HOST, false)
                isInSeat = intent.getBooleanExtra(EXTRA_IS_IN_SEAT, false)
                isMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, false)
                startForegroundWithNotification()
            }
            ACTION_UPDATE -> {
                roomName = intent.getStringExtra(EXTRA_ROOM_NAME) ?: roomName
                isHost = intent.getBooleanExtra(EXTRA_IS_HOST, isHost)
                isInSeat = intent.getBooleanExtra(EXTRA_IS_IN_SEAT, isInSeat)
                isMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, isMuted)
                updateNotification()
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_MIC_TOGGLE -> {
                // Forwarded to Flutter via EventChannel in AudioRoomServicePlugin
                AudioRoomServicePlugin.sendEvent(ACTION_MIC_TOGGLE)
            }
            ACTION_LEAVE_ROOM -> {
                AudioRoomServicePlugin.sendEvent(ACTION_LEAVE_ROOM)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundWithNotification() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Use ServiceInfo SDK constants — these are the correct values the manifest must also declare
            val serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            startForeground(NOTIFICATION_ID, notification, serviceType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        // Tap notification → open app
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Mic toggle action
        val micToggleIntent = Intent(this, AudioRoomForegroundService::class.java).apply {
            action = ACTION_MIC_TOGGLE
        }
        val micPendingIntent = PendingIntent.getService(
            this, 1, micToggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Leave room action
        val leaveIntent = Intent(this, AudioRoomForegroundService::class.java).apply {
            action = ACTION_LEAVE_ROOM
        }
        val leavePendingIntent = PendingIntent.getService(
            this, 2, leaveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val micIcon = if (isMuted)
            android.R.drawable.ic_lock_silent_mode
        else
            android.R.drawable.ic_btn_speak_now

        val micLabel = if (isMuted) "Unmute" else "Mute"

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(roomName)
            .setContentText("WiTalk Adda is active")
            .setSubText(if (isHost) "Host" else if (isInSeat) "Speaker" else "Listener")
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: CallStyle provides the Hang Up button natively.
            // Add mic toggle as an extra action (only for host/speakers).
            val caller = Person.Builder()
                .setName(roomName)
                .setImportant(true)
                .build()
            val callStyle = NotificationCompat.CallStyle.forOngoingCall(caller, leavePendingIntent)
            builder.setStyle(callStyle)

            if (isHost || isInSeat) {
                builder.addAction(
                    NotificationCompat.Action.Builder(
                        IconCompat.createWithResource(this, micIcon),
                        micLabel,
                        micPendingIntent
                    ).build()
                )
            }
        } else {
            // Android < 12: no CallStyle, add mic + leave actions manually
            if (isHost || isInSeat) {
                builder.addAction(
                    NotificationCompat.Action.Builder(
                        IconCompat.createWithResource(this, micIcon),
                        micLabel,
                        micPendingIntent
                    ).build()
                )
            }
            builder.addAction(
                NotificationCompat.Action.Builder(
                    IconCompat.createWithResource(this, android.R.drawable.ic_menu_close_clear_cancel),
                    "Leave",
                    leavePendingIntent
                ).build()
            )
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Shows active WiTalk Adda rooms"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }
}
