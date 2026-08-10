package com.witalk

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.graphics.drawable.IconCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.URL

/**
 * FCM Service for Flutter WiTalk.
 * Handles foreground, background, and terminated-state notifications.
 * Mirrors the RN FCMService.kt behavior exactly.
 */
class WiTalkFCMService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "WiTalkFCMService"

        // ── Channel IDs ──────────────────────────────────────────────────────
        const val CHANNEL_MESSAGES          = "witalk_messages"
        const val CHANNEL_GROUP_MESSAGES    = "witalk_group_messages"
        const val CHANNEL_PROFILE_LIKES     = "witalk_profile_likes"
        const val CHANNEL_MATCHES           = "witalk_matches"
        const val CHANNEL_NEARBY_JOIN       = "witalk_nearby_join"
        const val CHANNEL_SOCIAL            = "witalk_social_interactions"
        const val CHANNEL_SYSTEM            = "witalk_system"
        const val CHANNEL_SILENT            = "witalk_silent"
        const val CHANNEL_WALLET            = "witalk_wallet"
        const val CHANNEL_STREAK            = "witalk_streak"

        // ── Notification grouping keys ────────────────────────────────────────
        private const val GROUP_MESSAGES       = "com.witalk.MESSAGES"
        private const val GROUP_GROUP_MESSAGES = "com.witalk.GROUP_MESSAGES"
        private const val GROUP_SOCIAL         = "com.witalk.SOCIAL"

        // ── SharedPreferences ─────────────────────────────────────────────────
        private const val PREFS_NOTIFICATIONS  = "NotificationPreferences"
        private const val KEY_CONV_MESSAGES    = "conversation_messages"
        private const val KEY_GROUP_MESSAGES_P = "group_messages"
        private const val MAX_MESSAGES         = 10

        const val ADDA_PREFS            = "AddaState"
        const val KEY_IS_IN_ADDA        = "isInAdda"
        const val FCM_PREFS             = "FCMPreferences"
        const val KEY_USER_ID           = "user_id"

        // Types suppressed when the user is inside an Adda room
        private val ADDA_SUPPRESSIBLE = setOf(
            "post", "like", "comment", "comment_reply",
            "follow", "social_interactions",
            "adda", "topic_upvote", "reply_upvote",
            "profile_like", "profile_visit",
            "referral", "group_message", "streak_reminder"
        )

        // Inline reply
        const val KEY_TEXT_REPLY      = "key_text_reply"
        const val ACTION_REPLY        = "com.witalk.ACTION_REPLY"
        const val EXTRA_CONV_ID       = "conversation_id"
        const val EXTRA_SENDER_ID     = "sender_id"
        const val EXTRA_SENDER_NAME   = "sender_name"
        const val EXTRA_USER_ID       = "user_id"
        const val EXTRA_NOTIF_ID      = "notification_id"

        fun clearAllConversationMessages(context: Context) {
            context.getSharedPreferences(PREFS_NOTIFICATIONS, Context.MODE_PRIVATE)
                .edit().remove(KEY_CONV_MESSAGES).apply()
        }
    }

    private data class MessageData(
        val text: String,
        val timestamp: Long,
        val senderName: String,
        val senderIcon: IconCompat?
    )

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createAllChannels()
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token: ${token.take(30)}...")
        // Save locally — Flutter side will upload via FirebaseMessaging.instance.onTokenRefresh
        getSharedPreferences(FCM_PREFS, MODE_PRIVATE)
            .edit().putString("fcm_token", token).apply()
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "onMessageReceived: from=${remoteMessage.from}")

        val data = remoteMessage.data
        if (data.isEmpty()) return

        val type = data["type"] ?: ""

        // Own-adda broadcast suppression
        if (type == "adda" && data["action"] == "new_adda") {
            val hostId = data["hostId"]
            val myId   = getSharedPreferences(FCM_PREFS, MODE_PRIVATE).getString(KEY_USER_ID, null)
            if (!hostId.isNullOrBlank() && hostId == myId) return
        }

        // Own-channel-message suppression
        if (type == "channel_message") {
            val senderId = data["sender_id"]
            val myId     = getSharedPreferences(FCM_PREFS, MODE_PRIVATE).getString(KEY_USER_ID, null)
            if (!senderId.isNullOrBlank() && senderId == myId) return
        }

        // streak_reminder has its own dedicated builder
        if (type == "streak_reminder") {
            buildStreakNotification(data)
            return
        }

        val title = data["title"] ?: remoteMessage.notification?.title ?: "WiTalk"
        val body  = data["body"]  ?: remoteMessage.notification?.body  ?: ""
        val senderPic = data["senderProfilePic"] ?: data["channel_icon"]

        buildAndShowNotification(title, body, data, senderPic)
    }

    // ── Main notification builder ────────────────────────────────────────────

    private fun buildAndShowNotification(
        title: String,
        body: String,
        data: Map<String, String>,
        senderPicUrl: String?
    ) {
        val type          = data["type"]
        val isGroupMsg    = type == "group_message"
        val conversationId = data["conversationId"] ?: data["referenceId"] ?: ""
        val groupId        = data["groupId"] ?: ""
        val chatId         = if (isGroupMsg) groupId else conversationId

        val notifId = if (chatId.isNotBlank()) chatId.hashCode()
                      else System.currentTimeMillis().toInt()

        // Adda suppression
        val isInAdda = applicationContext
            .getSharedPreferences(ADDA_PREFS, MODE_PRIVATE)
            .getBoolean(KEY_IS_IN_ADDA, false)
        val suppressForAdda = isInAdda && type != null && ADDA_SUPPRESSIBLE.contains(type)

        // Channel selection
        val channelId = when {
            suppressForAdda                                                     -> CHANNEL_SILENT
            data["silent"] == "true"                                            -> CHANNEL_SILENT
            type == "profile_visit"                                             -> CHANNEL_SILENT
            type == "topic_upvote" || type == "reply_upvote"                   -> CHANNEL_SILENT
            isGroupMsg                                                          -> CHANNEL_GROUP_MESSAGES
            type == "message" || type == "message_request"
                    || type == "message_request_accepted"                       -> CHANNEL_MESSAGES
            type == "profile_like"                                              -> CHANNEL_PROFILE_LIKES
            type == "match"                                                     -> CHANNEL_MATCHES
            type == "social_interactions" && data["action"] == "nearby_join"   -> CHANNEL_NEARBY_JOIN
            type in listOf("like","comment","comment_reply","follow","social_interactions") -> CHANNEL_SOCIAL
            type in listOf("verification_approved","verification_rejected","system") -> CHANNEL_SYSTEM
            type == "wallet"                                                    -> CHANNEL_WALLET
            type == "streak_reminder"                                           -> CHANNEL_STREAK
            else                                                                -> CHANNEL_MESSAGES
        }

        val isSilent = suppressForAdda || data["silent"] == "true" || type == "profile_visit"
        val priority = if (isSilent) NotificationCompat.PRIORITY_LOW else NotificationCompat.PRIORITY_HIGH
        val visibility = if (isSilent) NotificationCompat.VISIBILITY_PRIVATE
                         else NotificationCompat.VISIBILITY_PUBLIC

        val pendingIntent = buildPendingIntent(type, data, notifId)

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(priority)
            .setVisibility(visibility)

        if (!isSilent) {
            builder.setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
        }

        // Grouping
        val groupKey = when {
            isGroupMsg -> GROUP_GROUP_MESSAGES
            type in listOf("like","comment","comment_reply","follow","social_interactions") -> GROUP_SOCIAL
            else -> GROUP_MESSAGES
        }
        builder.setGroup(groupKey)

        val senderName = data["senderName"] ?: title

        // Run in coroutine to load profile pics without blocking
        CoroutineScope(Dispatchers.IO).launch {
            var senderIcon: IconCompat? = null
            var largeBitmap: Bitmap? = null

            if (!senderPicUrl.isNullOrBlank()) {
                try {
                    val bmp = getBitmapFromUrl(senderPicUrl)
                    if (bmp != null) {
                        val circular = circularBitmap(bmp)
                        largeBitmap = circular
                        senderIcon = IconCompat.createWithBitmap(circular)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to load profile pic: ${e.message}")
                }
            }

            withContext(Dispatchers.Main) {
                if (largeBitmap != null) builder.setLargeIcon(largeBitmap)

                // MessagingStyle for private messages
                if (type == "message" && conversationId.isNotBlank()) {
                    val msgData = MessageData(body, System.currentTimeMillis(), senderName, senderIcon)
                    addMessageToConversation(conversationId, msgData)
                    applyMessagingStyle(builder, conversationId, false, null)
                }
                // MessagingStyle for group messages
                else if (isGroupMsg && groupId.isNotBlank()) {
                    val msgData = MessageData(body, System.currentTimeMillis(), senderName, senderIcon)
                    addMessageToGroup(groupId, msgData)
                    applyMessagingStyle(builder, groupId, true, data["groupName"])
                }
                // Channel message BigTextStyle
                else if (type == "channel_message") {
                    builder.setStyle(NotificationCompat.BigTextStyle().bigText(body).setBigContentTitle(title))
                }
                // BigTextStyle for long bodies
                else if (body.length > 50) {
                    builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
                }

                // Inline reply for private messages
                if (type == "message") {
                    addInlineReplyAction(builder, data, notifId)
                }

                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(notifId, builder.build())
                Log.d(TAG, "Notification shown: id=$notifId channel=$channelId type=$type")
            }
        }
    }

    // ── Streak notification ──────────────────────────────────────────────────

    private fun buildStreakNotification(data: Map<String, String>) {
        val title         = data["title"] ?: "🔥 Streak Reminder"
        val body          = data["body"]  ?: "Join Adda today to keep your streak alive!"
        val currentStreak = data["currentStreak"]?.toIntOrNull() ?: 0
        val midnightMs    = data["midnightISTMs"]?.toLongOrNull()
        val profilePicUrl = data["profilePicUrl"]?.takeIf { it.isNotBlank() }

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("notification_type", "streak_reminder")
            putExtra("currentStreak", currentStreak)
        }
        val pi = pendingIntentFlags().let { flags ->
            PendingIntent.getActivity(this, "streak_reminder".hashCode(), intent, flags)
        }

        val streakTitle = if (currentStreak > 0) "🔥 $currentStreak" else "🔥 0"
        val builder = NotificationCompat.Builder(this, CHANNEL_STREAK)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(streakTitle)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)

        if (midnightMs != null && midnightMs > System.currentTimeMillis()) {
            builder.setWhen(midnightMs).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(true)
            }
        }

        CoroutineScope(Dispatchers.IO).launch {
            var circular: Bitmap? = null
            if (!profilePicUrl.isNullOrBlank()) {
                try { circular = getBitmapFromUrl(profilePicUrl)?.let { circularBitmap(it) } } catch (_: Exception) {}
            }
            withContext(Dispatchers.Main) {
                if (circular != null) builder.setLargeIcon(circular)
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify("streak_reminder".hashCode(), builder.build())
            }
        }
    }

    // ── PendingIntent builder ────────────────────────────────────────────────

    private fun buildPendingIntent(type: String?, data: Map<String, String>, notifId: Int): PendingIntent {
        val intent = when {
            type == "message" && !data["senderUsername"].isNullOrBlank() ->
                deepLinkIntent("https://witalk.in/m/${data["senderUsername"]}")

            type == "message_request" && !data["senderUsername"].isNullOrBlank() ->
                deepLinkIntent("https://witalk.in/m/${data["senderUsername"]}")

            type == "message_request_accepted" && !data["acceptorUsername"].isNullOrBlank() ->
                deepLinkIntent("https://witalk.in/m/${data["acceptorUsername"]}")

            type == "social_interactions" && data["action"] == "nearby_join" && !data["newUserUsername"].isNullOrBlank() ->
                deepLinkIntent("https://witalk.in/${data["newUserUsername"]}")

            type == "post" && !data["suffix"].isNullOrBlank() ->
                deepLinkIntent("https://witalk.in/p/${data["suffix"]}")

            else -> {
                val deepLink = data["deep_link"]
                if (!deepLink.isNullOrBlank()) {
                    deepLinkIntent(deepLink)
                } else {
                    Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                        type?.let { putExtra("notification_type", it) }
                        data["referenceId"]?.let   { putExtra("reference_id", it) }
                        data["referenceType"]?.let { putExtra("reference_type", it) }
                        data["notificationId"]?.let{ putExtra("notification_id", it) }
                        data["conversationId"]?.let{ putExtra("conversationId", it) }
                        data["groupId"]?.let       { putExtra("groupId", it) }
                        data["groupName"]?.let     { putExtra("groupName", it) }
                        data["topicId"]?.let       { putExtra("topicId", it) }
                        data["notifType"]?.let     { putExtra("notifType", it) }
                        data["channel_id"]?.let    { putExtra("channel_id", it) }
                        data["channel_name"]?.let  { putExtra("channel_name", it) }
                        data["actor_id"]?.let      { putExtra("actor_id", it) }
                        data["postSuffix"]?.let    { putExtra("postSuffix", it) }
                        data["suffix"]?.let        { putExtra("suffix", it) }
                        data["room_id"]?.let       { putExtra("room_id", it) }
                        data["room_name"]?.let     { putExtra("room_name", it) }
                        data["topicId"]?.let       { putExtra("topicId", it) }
                        data["senderUsername"]?.let{ putExtra("sender_username", it) }
                        data["screen"]?.let        { putExtra("screen", it) }
                    }
                }
            }
        }

        return PendingIntent.getActivity(this, notifId, intent, pendingIntentFlags())
    }

    private fun deepLinkIntent(url: String) = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        setPackage(packageName)
    }

    private fun pendingIntentFlags() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

    // ── MessagingStyle ───────────────────────────────────────────────────────

    private fun applyMessagingStyle(
        builder: NotificationCompat.Builder,
        id: String,
        isGroup: Boolean,
        groupName: String?
    ) {
        val me = Person.Builder().setName("You").build()
        val style = NotificationCompat.MessagingStyle(me)
        if (isGroup) {
            style.conversationTitle = groupName ?: "Group"
            style.isGroupConversation = true
        }
        val messages = if (isGroup) loadGroupMessages(id) else loadConversationMessages(id)
        messages.forEach { msg ->
            val person = Person.Builder().setName(msg.senderName)
                .apply { msg.senderIcon?.let { setIcon(it) } }
                .build()
            style.addMessage(msg.text, msg.timestamp, person)
        }
        builder.setStyle(style)
    }

    // ── Inline reply ─────────────────────────────────────────────────────────

    private fun addInlineReplyAction(
        builder: NotificationCompat.Builder,
        data: Map<String, String>,
        notifId: Int
    ) {
        val convId   = data["conversationId"] ?: data["referenceId"] ?: return
        val userId   = data["recipientUserId"]
            ?: getSharedPreferences(FCM_PREFS, MODE_PRIVATE).getString(KEY_USER_ID, null)
            ?: return
        val senderName = data["senderName"] ?: "User"
        val senderId   = data["senderId"]

        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Reply to $senderName")
            .build()

        val replyIntent = Intent(this, WiTalkNotificationReplyReceiver::class.java).apply {
            action = ACTION_REPLY
            putExtra(EXTRA_CONV_ID,    convId)
            putExtra(EXTRA_SENDER_ID,  senderId)
            putExtra(EXTRA_SENDER_NAME,senderName)
            putExtra(EXTRA_USER_ID,    userId)
            putExtra(EXTRA_NOTIF_ID,   notifId)
        }

        val replyPiFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

        val replyPi = PendingIntent.getBroadcast(this, notifId, replyIntent, replyPiFlags)

        val action = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send, "Reply", replyPi
        )
            .addRemoteInput(remoteInput)
            .setAllowGeneratedReplies(true)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setShowsUserInterface(false)
            .build()

        builder.addAction(action)
    }

    // ── Notification channel creation ────────────────────────────────────────

    private fun createAllChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        createChannel(nm, CHANNEL_MESSAGES,       "Private Messages",     "Notifications for private messages",          NotificationManager.IMPORTANCE_HIGH,  "notification_sound", recreate = false)
        createChannel(nm, CHANNEL_GROUP_MESSAGES,  "Group Messages",       "Notifications for group chat messages",        NotificationManager.IMPORTANCE_HIGH,  "notification_sound", recreate = false)
        createChannel(nm, CHANNEL_PROFILE_LIKES,   "Profile Likes",        "Notifications when someone likes your profile",NotificationManager.IMPORTANCE_HIGH,  "like_profile",       recreate = true)
        createChannel(nm, CHANNEL_MATCHES,         "New Matches",          "Notifications for new matches",                NotificationManager.IMPORTANCE_HIGH,  "matched_profile",    recreate = true)
        createChannel(nm, CHANNEL_NEARBY_JOIN,     "Nearby Users",         "Notifications when someone nearby joins",      NotificationManager.IMPORTANCE_HIGH,  "nearyby_join",       recreate = true)
        createChannel(nm, CHANNEL_SOCIAL,          "Social Interactions",  "Likes, comments, replies, and follows",        NotificationManager.IMPORTANCE_DEFAULT,null,                 recreate = true)
        createChannel(nm, CHANNEL_SYSTEM,          "System",               "Official updates and system messages",         NotificationManager.IMPORTANCE_HIGH,  "system",             recreate = false)
        createChannel(nm, CHANNEL_WALLET,          "Wallet",               "Wallet credits and transactions",              NotificationManager.IMPORTANCE_HIGH,  "money_added",        recreate = true)
        createChannel(nm, CHANNEL_STREAK,          "Streak Reminders",     "Daily reminders to keep your Adda streak",    NotificationManager.IMPORTANCE_HIGH,  null,                 recreate = false)
        createSilentChannel(nm)
    }

    private fun createChannel(
        nm: NotificationManager,
        id: String,
        name: String,
        desc: String,
        importance: Int,
        soundFile: String?,
        recreate: Boolean
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (recreate) {
            nm.getNotificationChannel(id)?.let { nm.deleteNotificationChannel(id) }
        } else {
            if (nm.getNotificationChannel(id) != null) return
        }

        val soundUri = if (!soundFile.isNullOrBlank()) {
            Uri.parse("android.resource://$packageName/raw/$soundFile")
        } else {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        }

        val audioAttrs = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        val channel = NotificationChannel(id, name, importance).apply {
            description = desc
            enableLights(true)
            enableVibration(true)
            setShowBadge(true)
            setSound(soundUri, audioAttrs)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)
        Log.d(TAG, "Channel created: $id")
    }

    private fun createSilentChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm.getNotificationChannel(CHANNEL_SILENT) != null) return
        val channel = NotificationChannel(CHANNEL_SILENT, "Silent Notifications",
            NotificationManager.IMPORTANCE_LOW).apply {
            description = "Silent notifications — no sound or vibration"
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }
        nm.createNotificationChannel(channel)
        Log.d(TAG, "Silent channel created")
    }

    // ── Message history (SharedPreferences) ─────────────────────────────────

    private fun loadConversationMessages(convId: String): List<MessageData> {
        val prefs = getSharedPreferences(PREFS_NOTIFICATIONS, MODE_PRIVATE)
        val json  = prefs.getString(KEY_CONV_MESSAGES, "{}") ?: "{}"
        return try {
            JSONObject(json).optJSONArray(convId)?.let { arr ->
                (0 until arr.length()).map { i ->
                    arr.getJSONObject(i).let {
                        MessageData(it.getString("text"), it.getLong("timestamp"), it.getString("senderName"), null)
                    }
                }
            } ?: emptyList()
        } catch (_: Exception) { emptyList() }
    }

    private fun addMessageToConversation(convId: String, msg: MessageData) {
        saveMessage(KEY_CONV_MESSAGES, convId, msg)
    }

    private fun loadGroupMessages(groupId: String): List<MessageData> {
        val prefs = getSharedPreferences(PREFS_NOTIFICATIONS, MODE_PRIVATE)
        val json  = prefs.getString(KEY_GROUP_MESSAGES_P, "{}") ?: "{}"
        return try {
            JSONObject(json).optJSONArray(groupId)?.let { arr ->
                (0 until arr.length()).map { i ->
                    arr.getJSONObject(i).let {
                        MessageData(it.getString("text"), it.getLong("timestamp"), it.getString("senderName"), null)
                    }
                }
            } ?: emptyList()
        } catch (_: Exception) { emptyList() }
    }

    private fun addMessageToGroup(groupId: String, msg: MessageData) {
        saveMessage(KEY_GROUP_MESSAGES_P, groupId, msg)
    }

    private fun saveMessage(prefKey: String, id: String, msg: MessageData) {
        val prefs = getSharedPreferences(PREFS_NOTIFICATIONS, MODE_PRIVATE)
        try {
            val root = JSONObject(prefs.getString(prefKey, "{}") ?: "{}")
            val arr  = root.optJSONArray(id) ?: JSONArray()
            arr.put(JSONObject().put("text", msg.text).put("timestamp", msg.timestamp).put("senderName", msg.senderName))
            val trimmed = if (arr.length() > MAX_MESSAGES) {
                JSONArray().also { t -> for (i in arr.length() - MAX_MESSAGES until arr.length()) t.put(arr.get(i)) }
            } else arr
            root.put(id, trimmed)
            prefs.edit().putString(prefKey, root.toString()).apply()
        } catch (_: Exception) {}
    }

    // ── Image utils ──────────────────────────────────────────────────────────

    private fun getBitmapFromUrl(url: String): Bitmap? = try {
        val conn = URL(url).openConnection().apply { doInput = true; connect() }
        val bmp  = BitmapFactory.decodeStream(conn.getInputStream())
        conn.getInputStream().close()
        if (bmp != null) {
            val max = 256
            if (bmp.width > max || bmp.height > max) {
                val scale = max.toFloat() / maxOf(bmp.width, bmp.height)
                val scaled = Bitmap.createScaledBitmap(bmp, (bmp.width * scale).toInt(), (bmp.height * scale).toInt(), true)
                bmp.recycle()
                scaled
            } else bmp
        } else null
    } catch (_: Exception) { null }

    private fun circularBitmap(bmp: Bitmap): Bitmap {
        val size   = minOf(bmp.width, bmp.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint  = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawARGB(0, 0, 0, 0)
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(bmp, Rect(0, 0, size, size), Rect(0, 0, size, size), paint)
        return output
    }
}
