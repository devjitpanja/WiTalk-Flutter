package com.witalk

import android.content.Context
import android.media.MediaDrm
import android.os.Build
import android.provider.Settings
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * Device identifier bridge — mirrors RN DeviceIdentifiers native module.
 *
 * Channel: com.witalk/device_identifiers
 *
 * Methods:
 *   getAdvertisingInfo() → Map { gaid: String, isLimitAdTracking: Boolean }
 *   getAndroidId()       → String (ANDROID_ID)
 *   getWidevineInfo()    → Map { securityLevel: String, deviceId: String }
 */
class DeviceIdentifiersPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.witalk/device_identifiers"
        private val WIDEVINE_UUID = UUID(-0x121074568629b532L, -0x5c37d8232ae2de13L)
    }

    private val scope = CoroutineScope(Dispatchers.Main)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAdvertisingInfo" -> getAdvertisingInfo(result)
            "getAndroidId"       -> result.success(getAndroidId())
            "getWidevineInfo"    -> getWidevineInfo(result)
            else                 -> result.notImplemented()
        }
    }

    // ── Google Advertising ID ────────────────────────────────────────────────

    private fun getAdvertisingInfo(result: MethodChannel.Result) {
        scope.launch {
            try {
                val info = withContext(Dispatchers.IO) {
                    AdvertisingIdClient.getAdvertisingIdInfo(context)
                }
                val gaid = info.id ?: ""
                val isLimit = info.isLimitAdTrackingEnabled
                // All-zeros means the user has opted out / deleted their ad ID
                val isDeleted = gaid == "00000000-0000-0000-0000-000000000000"
                result.success(mapOf(
                    "gaid" to if (isLimit || isDeleted) "" else gaid,
                    "isLimitAdTracking" to isLimit,
                    "isAdIdDeleted" to isDeleted,
                ))
            } catch (e: Exception) {
                // Play Services unavailable or user opted out completely
                result.success(mapOf(
                    "gaid" to "",
                    "isLimitAdTracking" to true,
                    "isAdIdDeleted" to false,
                ))
            }
        }
    }

    // ── Android ID ───────────────────────────────────────────────────────────

    private fun getAndroidId(): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    // ── Widevine DRM ─────────────────────────────────────────────────────────

    private fun getWidevineInfo(result: MethodChannel.Result) {
        scope.launch {
            try {
                val (secLevel, deviceId) = withContext(Dispatchers.IO) {
                    var drm: MediaDrm? = null
                    try {
                        drm = MediaDrm(WIDEVINE_UUID)
                        val level = drm.getPropertyString("securityLevel") ?: "unknown"
                        @Suppress("DEPRECATION")
                        val idBytes = drm.getPropertyByteArray("deviceUniqueId")
                        val id = idBytes?.let { bytes ->
                            bytes.joinToString("") { "%02x".format(it) }
                        } ?: ""
                        Pair(level, id)
                    } finally {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            drm?.close()
                        } else {
                            @Suppress("DEPRECATION")
                            drm?.release()
                        }
                    }
                }
                result.success(mapOf("securityLevel" to secLevel, "deviceId" to deviceId))
            } catch (e: Exception) {
                result.success(mapOf("securityLevel" to "unknown", "deviceId" to ""))
            }
        }
    }
}
