package com.witalk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // VPN / emulator / Frida detection
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VpnDetectorPlugin.CHANNEL
        ).setMethodCallHandler(VpnDetectorPlugin(applicationContext))

        // Google Play Install Referrer
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            InstallReferrerPlugin.CHANNEL
        ).setMethodCallHandler(InstallReferrerPlugin(applicationContext))

        // Audio room foreground service (WhatsApp-style background calling)
        val audioRoomPlugin = AudioRoomServicePlugin(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AudioRoomServicePlugin.METHOD_CHANNEL
        ).setMethodCallHandler(audioRoomPlugin)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AudioRoomServicePlugin.EVENT_CHANNEL
        ).setStreamHandler(audioRoomPlugin)

        // Screenshot prevention — pass `this` (the Activity) directly so the plugin
        // can call addFlags/clearFlags without going through ActivityAware lifecycle.
        val screenshotPlugin = ScreenshotPreventPlugin(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ScreenshotPreventPlugin.METHOD_CHANNEL
        ).setMethodCallHandler(screenshotPlugin)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ScreenshotPreventPlugin.EVENT_CHANNEL
        ).setStreamHandler(screenshotPlugin)

        // Play Integrity API
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppIntegrityPlugin.CHANNEL
        ).setMethodCallHandler(AppIntegrityPlugin(applicationContext))

        // Device identifiers (GAID, Android ID, Widevine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceIdentifiersPlugin.CHANNEL
        ).setMethodCallHandler(DeviceIdentifiersPlugin(applicationContext))

        // FCM preferences bridge — lets Dart write user_id/api_base_url and
        // clear notifications from the tray when the app comes to foreground.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.witalk/fcm_prefs"
        ).setMethodCallHandler { call, result ->
            val nm = applicationContext.getSystemService(android.app.NotificationManager::class.java)
            when (call.method) {
                "saveUserId" -> {
                    val userId = call.argument<String>("userId") ?: ""
                    applicationContext.getSharedPreferences(WiTalkFCMService.FCM_PREFS, MODE_PRIVATE)
                        .edit().putString(WiTalkFCMService.KEY_USER_ID, userId).apply()
                    result.success(null)
                }
                "saveApiBaseUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    applicationContext.getSharedPreferences(WiTalkFCMService.FCM_PREFS, MODE_PRIVATE)
                        .edit().putString("api_base_url", url).apply()
                    result.success(null)
                }
                // Called when app comes to foreground — clears tray + message history
                "clearAllNotifications" -> {
                    nm.cancelAll()
                    WiTalkFCMService.clearAllConversationMessages(applicationContext)
                    result.success(null)
                }
                // Called when a specific chat/group is opened
                "clearChatNotifications" -> {
                    val conversationId = call.argument<String>("conversationId") ?: ""
                    if (conversationId.isNotEmpty()) {
                        val prefs = applicationContext.getSharedPreferences("NotificationPreferences", MODE_PRIVATE)
                        val root = try { org.json.JSONObject(prefs.getString("conversation_messages", "{}") ?: "{}") } catch (_: Exception) { org.json.JSONObject() }
                        root.remove(conversationId)
                        prefs.edit().putString("conversation_messages", root.toString()).apply()
                        nm.cancel(conversationId.hashCode())
                    }
                    result.success(null)
                }
                "clearGroupNotifications" -> {
                    val groupId = call.argument<String>("groupId") ?: ""
                    if (groupId.isNotEmpty()) {
                        val prefs = applicationContext.getSharedPreferences("NotificationPreferences", MODE_PRIVATE)
                        val root = try { org.json.JSONObject(prefs.getString("group_messages", "{}") ?: "{}") } catch (_: Exception) { org.json.JSONObject() }
                        root.remove(groupId)
                        prefs.edit().putString("group_messages", root.toString()).apply()
                        nm.cancel(groupId.hashCode())
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
