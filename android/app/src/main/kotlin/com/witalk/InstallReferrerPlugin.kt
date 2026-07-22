package com.witalk

import android.os.RemoteException
import android.util.Log
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.Context

/**
 * Flutter MethodChannel bridge for Google Play Install Referrer API.
 * Logic ported from RN InstallReferrerModule.java — supports Android 13+.
 *
 * Channel: com.witalk/install_referrer
 * Methods: getInstallReferrerInfo, isInstallReferrerAvailable
 */
class InstallReferrerPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.witalk/install_referrer"
        private const val TAG = "InstallReferrerPlugin"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstallReferrerInfo"      -> getInstallReferrerInfo(result)
            "isInstallReferrerAvailable"  -> result.success(isInstallReferrerAvailable())
            else                          -> result.notImplemented()
        }
    }

    private fun getInstallReferrerInfo(result: MethodChannel.Result) {
        try {
            val client = InstallReferrerClient.newBuilder(context).build()
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                val details: ReferrerDetails = client.installReferrer
                                val map = mapOf<String, Any?>(
                                    "installReferrer"                      to details.installReferrer,
                                    "referrerClickTimestampSeconds"        to details.referrerClickTimestampSeconds.toDouble(),
                                    "installBeginTimestampSeconds"         to details.installBeginTimestampSeconds.toDouble(),
                                    "referrerClickTimestampServerSeconds"  to details.referrerClickTimestampServerSeconds.toDouble(),
                                    "installBeginTimestampServerSeconds"   to details.installBeginTimestampServerSeconds.toDouble(),
                                    "installVersion"                       to details.installVersion,
                                    "googlePlayInstant"                    to details.googlePlayInstantParam
                                )
                                Log.d(TAG, "Install Referrer retrieved: ${details.installReferrer}")
                                client.endConnection()
                                result.success(map)
                            } catch (e: RemoteException) {
                                Log.e(TAG, "RemoteException getting referrer details", e)
                                client.endConnection()
                                result.error("REMOTE_EXCEPTION", e.message, null)
                            }
                        }
                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                            result.error("FEATURE_NOT_SUPPORTED", "Install Referrer API not available on this device", null)
                        }
                        InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE -> {
                            result.error("SERVICE_UNAVAILABLE", "Google Play Store connection failed", null)
                        }
                        else -> {
                            result.error("UNKNOWN_ERROR", "Unexpected response code: $responseCode", null)
                        }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    Log.w(TAG, "Install Referrer service disconnected")
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Exception initializing Install Referrer client", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun isInstallReferrerAvailable(): Boolean {
        return try {
            context.packageManager.hasSystemFeature("com.google.android.gms")
        } catch (e: Exception) {
            false
        }
    }
}
