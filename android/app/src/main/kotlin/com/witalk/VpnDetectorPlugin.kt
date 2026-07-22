package com.witalk

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Flutter MethodChannel bridge for VPN / emulator / Frida detection.
 * Logic ported 1:1 from RN VpnDetectorModule.kt — no functionality removed.
 *
 * Channel: com.witalk/vpn_detector
 * Methods: isVpnActive, isAdvancedEmulator, isFridaDetected
 */
class VpnDetectorPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.witalk/vpn_detector"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isVpnActive"         -> result.success(isVpnActive())
            "isAdvancedEmulator"  -> result.success(isAdvancedEmulator())
            "isFridaDetected"     -> result.success(isFridaDetected())
            else                  -> result.notImplemented()
        }
    }

    // ── VPN detection ────────────────────────────────────────────────────────

    private fun isVpnActive(): Boolean {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val caps = cm.getNetworkCapabilities(cm.activeNetwork)
                caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            } else {
                @Suppress("DEPRECATION")
                cm.activeNetworkInfo?.type == ConnectivityManager.TYPE_VPN
            }
        } catch (e: Exception) {
            false
        }
    }

    // ── Advanced emulator detection (9 layers) ───────────────────────────────

    private fun isAdvancedEmulator(): Boolean {
        // Layer 1: Known emulator file paths
        val knownFiles = arrayOf(
            "/system/lib/libc_malloc_debug_qemu.so", "/sys/qemu_trace",
            "/system/bin/qemu-props", "/dev/socket/qemud", "/dev/qemu_pipe",
            "/dev/goldfish_pipe", "/dev/socket/baseband_genyd", "/dev/socket/genyd",
            "/system/bin/androVM-prop", "/system/xbin/microvirtd",
            "/system/lib/libdroid4x.so", "/system/bin/windroyed",
            "/system/bin/nox-prop", "/system/lib/libnoxspeedup.so",
            "/system/bin/ttVM-prop", "/system/bin/nemuVM-prop",
            "/system/bin/ld_emu_prop", "/system/lib/libldemu.so",
            "/mnt/windows/BstSharedFolder", "/mnt/shared/BlueStacks",
            "/data/bluestacks.prop", "/mnt/prebundledapps",
            "/system/lib/libhoudini.so", "/system/lib/arm/libhoudini.so",
            "/system/bin/houdini"
        )
        if (knownFiles.any { File(it).exists() }) return true

        // Layer 2: Build property heuristics
        try {
            val hw = Build.HARDWARE.lowercase(); val board = Build.BOARD.lowercase()
            val bootloader = Build.BOOTLOADER.lowercase(); val model = Build.MODEL.lowercase()
            val manufacturer = Build.MANUFACTURER.lowercase(); val user = Build.USER.lowercase()
            val device = Build.DEVICE.lowercase(); val product = Build.PRODUCT.lowercase()
            val display = Build.DISPLAY.lowercase(); val brand = Build.BRAND.lowercase()
            val host = Build.HOST.lowercase(); val tags = Build.TAGS.lowercase()
            if (hw.contains("nox") || hw.contains("vbox86") || hw.contains("bluestacks") ||
                hw.contains("goldfish") || hw.contains("ranchu") || hw.contains("waydroid") ||
                board.contains("nox") || board.contains("goldfish") ||
                bootloader.contains("nox") ||
                user.contains("bluestacks") || user.contains("genymotion") ||
                manufacturer.contains("genymotion") || manufacturer.contains("bluestacks") ||
                manufacturer.contains("andy") || manufacturer.contains("nox") ||
                model.contains("google_sdk") || model.contains("emulator") ||
                model.contains("sdk_gphone") || model.contains("android sdk built for x86") ||
                model.contains("vmos") || model.contains("bluestacks") ||
                product.contains("vbox86p") || product.contains("emulator") ||
                product.contains("simulator") || product.contains("waydroid") ||
                product.contains("bluestacks") || product.contains("nox") ||
                display.contains("vbox86p") || display.contains("bluestacks") ||
                brand.contains("bluestacks") || host.contains("bluestacks") ||
                host.contains("genymotion") || tags == "test-keys" ||
                (brand.startsWith("generic") && device.startsWith("generic")) ||
                Build.FINGERPRINT.startsWith("generic") || Build.FINGERPRINT.startsWith("unknown")
            ) return true
        } catch (e: Exception) { /* Ignore */ }

        // Layer 3: SystemProperties via reflection
        try {
            val getMethod = Class.forName("android.os.SystemProperties").getMethod("get", String::class.java)
            val props = mapOf(
                "ro.kernel.qemu" to { v: String -> v == "1" },
                "ro.bluestacks.mode" to { v: String -> v.isNotEmpty() },
                "ro.bluestacks" to { v: String -> v.isNotEmpty() },
                "ro.nox.version" to { v: String -> v.isNotEmpty() },
                "ro.leapdroid.sim" to { v: String -> v.isNotEmpty() },
                "ro.vmos.isCloud" to { v: String -> v.isNotEmpty() },
                "init.svc.qemud" to { v: String -> v.isNotEmpty() },
                "init.svc.qemu-props" to { v: String -> v.isNotEmpty() },
                "ro.product.cpu.abi" to { v: String -> v.contains("x86") }
            )
            for ((prop, check) in props) {
                val value = (getMethod.invoke(null, prop) as? String ?: "").lowercase()
                if (check(value)) return true
            }
        } catch (e: Exception) { /* Reflection unavailable */ }

        // Layer 4: getprop exec
        val propsToQuery = mapOf(
            "ro.bluestacks.mode" to { v: String -> v.isNotEmpty() },
            "ro.bluestacks" to { v: String -> v.isNotEmpty() },
            "ro.build.tags" to { v: String -> v == "test-keys" },
            "ro.kernel.qemu" to { v: String -> v == "1" },
            "ro.nox.version" to { v: String -> v.isNotEmpty() }
        )
        for ((prop, check) in propsToQuery) {
            try {
                val proc = Runtime.getRuntime().exec(arrayOf("getprop", prop))
                val value = proc.inputStream.bufferedReader().use { it.readLine() }?.lowercase()?.trim() ?: ""
                proc.destroy()
                if (check(value)) return true
            } catch (e: Exception) { /* Ignore */ }
        }

        // Layer 5: Emulator package detection
        val emulatorPackages = listOf(
            "com.bluestacks.home", "com.bluestacks.appmart", "com.bignox.app.store.hd",
            "com.bignox.launcher", "com.vphone.launcher", "com.ldmnq.launcher3",
            "com.microvirt.launcher", "com.genymotion.superuser", "com.leapdroid.launcher",
            "com.andyroid.andyhelper", "com.windowsgames.launcher"
        )
        val pm = context.packageManager
        for (pkg in emulatorPackages) {
            try { pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES); return true } catch (e: PackageManager.NameNotFoundException) { /* Not installed */ }
        }

        // Layer 6: /proc/cpuinfo hypervisor scan
        try {
            val cpuInfo = File("/proc/cpuinfo").readText().lowercase()
            if (listOf("hypervisor", "qemu", "virtual", "vbox", "vmware", "kvm").any { cpuInfo.contains(it) }) return true
        } catch (e: Exception) { /* Ignore */ }

        // Layer 7: Virtual network interface scan
        try {
            val netDev = File("/proc/net/dev").readText().lowercase()
            if (listOf("vboxnet", "veth", "virbr", "docker", "bst").any { netDev.contains(it) }) return true
        } catch (e: Exception) { /* Ignore */ }

        // Layer 8: Sensor checks
        try {
            val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val hasAccel = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null
            val hasGyro  = sm.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
            if (!hasAccel && !hasGyro) return true
            val emulatorVendors = listOf("bluestacks", "genymotion", "nox", "memu", "ldplayer", "andy", "microvirt")
            val sensorTypes = intArrayOf(Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_GYROSCOPE, Sensor.TYPE_MAGNETIC_FIELD)
            for (type in sensorTypes) {
                val sensor = sm.getDefaultSensor(type) ?: continue
                if (emulatorVendors.any { sensor.vendor.lowercase().contains(it) }) return true
            }
        } catch (e: Exception) { /* Ignore */ }

        // Layer 9: Storage capacity anomaly
        try {
            val statFs = android.os.StatFs(android.os.Environment.getDataDirectory().path)
            val totalGb = (statFs.blockCountLong * statFs.blockSizeLong) / (1024.0 * 1024.0 * 1024.0)
            val realRanges = listOf(15.0..30.0, 42.0..65.0, 95.0..125.0, 210.0..252.0, 440.0..496.0, 880.0..990.0)
            if (totalGb > 10.0 && realRanges.none { totalGb in it }) return true
        } catch (e: Exception) { /* Ignore */ }

        return false
    }

    // ── Frida / Xposed detection ─────────────────────────────────────────────

    private fun isFridaDetected(): Boolean {
        // 1. /proc/self/maps signatures
        try {
            val maps = File("/proc/self/maps").readText().lowercase()
            if (listOf("frida", "gum-js-loop", "gmain", "linjector", "libfrida", "frida-agent", "frida-gadget", "re.frida").any { maps.contains(it) }) return true
        } catch (e: Exception) { /* Ignore */ }

        // 2. Probe port 27042 (Frida server default)
        try {
            Socket().use { s ->
                s.connect(InetSocketAddress("127.0.0.1", 27042), 150)
                return true
            }
        } catch (e: Exception) { /* Port closed = good */ }

        // 3. /proc/self/fd symlinks
        try {
            File("/proc/self/fd").listFiles()?.forEach { fd ->
                try {
                    val link = fd.canonicalPath.lowercase()
                    if (link.contains("frida") || link.contains("linjector")) return true
                } catch (e: Exception) { /* Ignore */ }
            }
        } catch (e: Exception) { /* Ignore */ }

        // 4. Xposed files
        val xposedFiles = listOf(
            "/system/framework/XposedBridge.jar", "/system/lib/libxposed_art.so",
            "/system/xposed.prop", "/data/data/de.robv.android.xposed.installer"
        )
        if (xposedFiles.any { File(it).exists() }) return true

        // 5. Xposed class loading
        return try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            true
        } catch (e: ClassNotFoundException) {
            false
        }
    }
}
