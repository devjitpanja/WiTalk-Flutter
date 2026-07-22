package com.witalk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
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
    }
}
