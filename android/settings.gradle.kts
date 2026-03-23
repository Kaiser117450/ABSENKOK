pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // v7.0 sengaja tetap di Kotlin 1.9.25: Flutter warning diakui, tetapi release hardening ini tidak
    // mengizinkan surprise upgrade atau bypass flag sampai kompatibilitas nfc_manager terhadap Kotlin 2.x dibuktikan.
    id("org.jetbrains.kotlin.android") version "1.9.25" apply false
}

include(":app")
