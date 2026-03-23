import org.gradle.api.GradleException
import java.util.Properties

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")

if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

val requestedTasks = gradle.startParameter.taskNames.map { it.substringAfterLast(':').lowercase() }
val releaseTaskRequested = requestedTasks.any { taskName ->
    taskName.contains("release") || taskName in setOf("assemble", "build", "bundle", "package")
}

fun requireReleaseProperty(name: String): String {
    val value = keyProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException(
            "Release signing requires '$name' in android/key.properties. " +
                "Copy android/key.properties.example and provide your private upload key values."
        )
    }
    return value
}

if (releaseTaskRequested) {
    if (!keyPropertiesFile.exists()) {
        throw GradleException(
            "Release signing requires private android/key.properties. " +
                "Copy android/key.properties.example and keep the real file out of source control."
        )
    }

    val releaseStoreFilePath = requireReleaseProperty("storeFile")
    requireReleaseProperty("storePassword")
    requireReleaseProperty("keyPassword")
    requireReleaseProperty("keyAlias")

    if (!rootProject.file(releaseStoreFilePath).exists()) {
        throw GradleException(
            "Release signing requires the private upload keystore referenced by " +
                "android/key.properties at '$releaseStoreFilePath'."
        )
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.enakko.absensi_enakko_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.enakko.absensi_enakko_flutter"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            storeFile = keyProperties.getProperty("storeFile")?.trim()?.takeIf { it.isNotEmpty() }?.let {
                rootProject.file(it)
            }
            storePassword = keyProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // ProGuard — removes unused Java/Kotlin code
            isMinifyEnabled = true
            // Remove unused Android resources (layouts, drawables, etc.)
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "ABSENKOK-v${variant.versionName}.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
