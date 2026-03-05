package com.enakko.absensi_enakko_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Helper untuk menampilkan custom "Live Activity" notification bergaya Grab.
 * Dijalankan via MethodChannel dari Dart (kiosk_background_service.dart).
 *
 * Arsitektur (mengikuti pendekatan Grab):
 *  - Custom notification dengan RemoteViews (compact + expanded layout)
 *  - setOngoing(true) → tidak bisa di-swipe user
 *  - setOnlyAlertOnce(true) → heads-up hanya saat pertama show, update silent
 *  - IMPORTANCE_HIGH untuk channel → muncul sebagai heads-up pertama kali
 *  - Collapsed: icon + outlet name + body + live clock (hijau)
 *  - Expanded: full info + NFC status + LIVE badge
 *
 * Return value: show() / update() → Boolean
 *  - true  = notification berhasil di-post
 *  - false = gagal (SecurityException — POST_NOTIFICATIONS belum diberikan)
 *  Dart membaca nilai ini: jika false, aktifkan fallback via flutter_local_notifications.
 */
object KioskNotificationHelper {

    private const val CHANNEL_ID   = "absensi_enakko_pill"
    private const val CHANNEL_NAME = "Kiosk Status"
    const val NOTIF_ID             = 300

    /** Buat notification channel — panggil sekali di MainActivity.configureFlutterEngine(). */
    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH  // heads-up saat pertama muncul
            ).apply {
                description = "Status kiosk absensi aktif — notifikasi live real-time"
                setSound(null, null)     // silent — tidak perlu bunyi
                enableVibration(false)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    /**
     * Tampilkan Live Activity notification (atau update jika sudah ada).
     * Returns true jika berhasil di-post, false jika gagal (izin belum diberikan).
     * Dart membaca return value ini untuk memutuskan apakah fallback perlu diaktifkan.
     */
    fun show(context: Context, title: String, body: String): Boolean {
        val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())

        // ── Compact (collapsed) view ──
        val compactView = RemoteViews(context.packageName, R.layout.notification_kiosk).apply {
            setTextViewText(R.id.notif_title, title)
            setTextViewText(R.id.notif_body, body)
            setTextViewText(R.id.notif_time, timeStr)
        }

        // ── Expanded view ──
        val expandedView = RemoteViews(context.packageName, R.layout.notification_kiosk_expanded).apply {
            setTextViewText(R.id.notif_exp_title, title)
            setTextViewText(R.id.notif_exp_subtitle, body)
            setTextViewText(R.id.notif_exp_time, timeStr)
            setTextViewText(R.id.notif_exp_status, "● Aktif")
        }

        // Tap notification → open app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(compactView)
            .setCustomBigContentView(expandedView)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)           // tidak bisa di-swipe
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)     // heads-up hanya pertama kali
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .build()

        return try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, notif)
            true   // sukses — notification ter-post
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS permission not granted on Android 13+
            // Return false → Dart akan trigger fallback flutter_local_notifications
            false
        }
    }

    /** Update teks notification — same as show, Android replaces by same ID.
     *  Returns true jika berhasil, false jika gagal. */
    fun update(context: Context, title: String, body: String): Boolean = show(context, title, body)

    /** Hapus Live Activity notification (dipanggil saat kiosk stop). */
    fun dismiss(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIF_ID)
    }
}
