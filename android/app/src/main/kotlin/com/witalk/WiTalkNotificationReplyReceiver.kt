package com.witalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Handles inline notification reply actions for private chat messages.
 */
class WiTalkNotificationReplyReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WiTalkReplyReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != WiTalkFCMService.ACTION_REPLY) return

        val remoteInput = RemoteInput.getResultsFromIntent(intent) ?: return
        val replyText = remoteInput.getCharSequence(WiTalkFCMService.KEY_TEXT_REPLY)
            ?.toString()?.takeIf { it.isNotBlank() } ?: return

        val conversationId = intent.getStringExtra(WiTalkFCMService.EXTRA_CONV_ID) ?: return
        val userId         = intent.getStringExtra(WiTalkFCMService.EXTRA_USER_ID)  ?: return
        val senderName     = intent.getStringExtra(WiTalkFCMService.EXTRA_SENDER_NAME)
        val notifId        = intent.getIntExtra(WiTalkFCMService.EXTRA_NOTIF_ID, -1)

        // Dismiss the notification immediately
        if (notifId != -1) NotificationManagerCompat.from(context).cancel(notifId)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prefs      = context.getSharedPreferences(WiTalkFCMService.FCM_PREFS, Context.MODE_PRIVATE)
                val apiBaseUrl = prefs.getString("api_base_url", null)
                    ?: run { Log.e(TAG, "api_base_url missing"); return@launch }

                val url        = URL("$apiBaseUrl/v1/chat/message/send")
                val conn       = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 10_000
                conn.readTimeout    = 10_000

                val body = JSONObject().apply {
                    put("conversationId", conversationId)
                    put("senderId", userId)
                    put("message", replyText)
                    put("type", "text")
                    put("fromNotification", true)
                }

                OutputStreamWriter(conn.outputStream).use {
                    it.write(body.toString())
                    it.flush()
                }

                Log.d(TAG, "Reply sent — responseCode=${conn.responseCode}")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send reply", e)
            }
        }
    }
}
