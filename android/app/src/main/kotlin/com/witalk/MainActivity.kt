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
    }
}
