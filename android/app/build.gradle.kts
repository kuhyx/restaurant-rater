import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, kept out of the repo. CI writes key.properties from
// repository secrets; locally the file is absent and the build falls back to
// the debug key so `flutter run --release` still works. Every release APK is
// signed with the one shared key, so updates install over each other instead
// of forcing an uninstall.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.kuhy.restaurant_rater"
    // Pinned above `flutter.compileSdkVersion` (36 on Flutter 3.47.2):
    // flutter_secure_storage 11.0.0 -- pulled in by crdt_sync_flutter to hold
    // the sync account password -- declares AAR metadata requiring API 37, and
    // the build fails outright below it.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        // Only declared when key.properties exists; otherwise the release
        // build falls back to the debug key below.
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                // Absolute path: key.properties is read from android/, but
                // Gradle's file() resolves against android/app/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // Deliberately no product flavors, unlike punchme: there is nothing here a
    // sandbox build would need to be kept away from, and declaring a flavor
    // would rename the artefact to app-<flavor>-release.apk, which both
    // ci_mirror.sh and phone_deploy.sh would then fail to find.

    defaultConfig {
        applicationId = "com.kuhy.restaurant_rater"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml, which CI and
        // scripts/phone_deploy.sh both override with the commit count.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // The debug fallback keeps `flutter run --release` working with no
            // keystore present. CI must never take it -- the apksigner verify
            // step in ci.yml fails the build if it does.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
