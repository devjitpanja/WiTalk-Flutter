package com.witalk

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * Play Integrity API bridge.
 *
 * Dart invocation: AppIntegrity.requestToken(nonce)
 *   → returns Map { "token": String, "nonce": String }
 *   → on error returns Map { "error": String }
 *
 * Channel: com.witalk/app_integrity
 * Method:  requestIntegrityToken(nonce: String)
 *
 * iOS equivalent: DCAppAttestService / DeviceCheck — see AppIntegrityPlugin.swift.
 */
class AppIntegrityPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.witalk/app_integrity"
    }

    private val scope = CoroutineScope(Dispatchers.Main)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "requestIntegrityToken") {
            result.notImplemented()
            return
        }

        val nonce = call.argument<String>("nonce") ?: run {
            result.error("MISSING_NONCE", "Nonce is required", null)
            return
        }

        scope.launch {
            try {
                val manager = IntegrityManagerFactory.create(context)
                val request = IntegrityTokenRequest.builder()
                    .setNonce(nonce)
                    .build()

                val response = manager.requestIntegrityToken(request).await()
                result.success(mapOf("token" to response.token(), "nonce" to nonce))
            } catch (e: Exception) {
                // Soft-fail: integrity not available on some devices (no Play Services, etc.)
                result.success(mapOf("error" to (e.message ?: "Play Integrity unavailable")))
            }
        }
    }
}
