# Flutter default rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep flutter_foreground_task service
-keep class com.pravera.flutter_foreground_task.** { *; }

# Keep NFC classes
-keep class android.nfc.** { *; }

# Keep custom notification helper
-keep class com.enakko.absensi_enakko_flutter.KioskNotificationHelper { *; }

# Keep RemoteViews layout references
-keepclassmembers class **.R$layout { *; }
-keepclassmembers class **.R$id { *; }
-keepclassmembers class **.R$mipmap { *; }
-keepclassmembers class **.R$drawable { *; }

# Supabase / Kotlin serialization
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# OkHttp (used by Supabase under the hood)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Flutter overlay window
-keep class com.phan_tech.flutter_overlay_window.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Prevent R8 from stripping notification-related classes
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# Google Play Core — referenced by Flutter deferred components but not used
# Without these rules, R8 fails with "Missing class" errors
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
