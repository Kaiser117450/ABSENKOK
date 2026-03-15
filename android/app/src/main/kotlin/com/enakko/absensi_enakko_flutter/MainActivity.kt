package com.enakko.absensi_enakko_flutter

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val notifChannel  = "com.enakko.kiosk/notification"
    private val miuiChannel   = "com.enakko.kiosk/miui_perms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Buat notification channel untuk custom pill (hanya berlaku jika belum ada)
        KioskNotificationHelper.createChannel(applicationContext)

        // ── MethodChannel: custom pill notification ────────────────────────────
        // show() dan update() sekarang mengembalikan Boolean ke Dart:
        //   true  = notification berhasil di-post
        //   false = gagal (POST_NOTIFICATIONS belum diberikan → SecurityException)
        // Dart akan aktifkan fallback flutter_local_notifications jika false.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notifChannel
        ).setMethodCallHandler { call, result ->
            val title = call.argument<String>("title") ?: "Kiosk Aktif"
            val body  = call.argument<String>("body")  ?: "Tempelkan kartu NFC"
            when (call.method) {
                "show"    -> {
                    val success = KioskNotificationHelper.show(applicationContext, title, body)
                    result.success(success)   // true = posted, false = permission denied
                }
                "update"  -> {
                    val success = KioskNotificationHelper.update(applicationContext, title, body)
                    result.success(success)
                }
                "dismiss" -> {
                    KioskNotificationHelper.dismiss(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── MethodChannel: MIUI/HyperOS per-app permissions & detection ────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            miuiChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Buka halaman izin per-app MIUI secara langsung
                "openMiuiPermissions" -> {
                    val opened = tryOpenMiuiPermissions()
                    if (!opened) {
                        // Fallback: buka App Details standar Android
                        openAndroidAppSettings()
                    }
                    result.success(opened)
                }
                // Deteksi apakah device menjalankan MIUI / HyperOS
                "isMiui" -> {
                    result.success(isMiuiOrHyperOs())
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    /** Coba buka halaman izin per-app MIUI (PermissionsEditorActivity). */
    private fun tryOpenMiuiPermissions(): Boolean {
        return try {
            val intent = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity"
                )
                putExtra("extra_pkgname", packageName)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Fallback: buka App Details standar Android. */
    private fun openAndroidAppSettings() {
        try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null)
            )
            startActivity(intent)
        } catch (e: Exception) {}
    }

    /** Deteksi MIUI atau HyperOS via system properties. */
    private fun isMiuiOrHyperOs(): Boolean {
        return try {
            val sysPropClass = Class.forName("android.os.SystemProperties")
            val getMethod    = sysPropClass.getMethod("get", String::class.java)
            val miuiVer  = getMethod.invoke(null, "ro.miui.ui.version.name")?.toString() ?: ""
            val hyperVer = getMethod.invoke(null, "ro.mi.os.version.name")?.toString()  ?: ""
            miuiVer.isNotEmpty() || hyperVer.isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }
}
