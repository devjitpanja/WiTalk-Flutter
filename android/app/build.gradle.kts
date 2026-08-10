plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.witalk"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = file("mykeystore.jks")
            storePassword = "1234567890"
            keyAlias = "Manu"
            keyPassword = "1234567890"
        }
    }

    defaultConfig {
        applicationId = "com.witalk"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Google Play Install Referrer API (used by InstallReferrerPlugin)
    implementation("com.android.installreferrer:installreferrer:2.2")
    // Play Integrity API (used by AppIntegrityPlugin)
    implementation("com.google.android.play:integrity:1.4.0")
    // Google Advertising ID / GAID (used by DeviceIdentifiersPlugin)
    implementation("com.google.android.gms:play-services-ads-identifier:18.1.0")
    // Kotlin coroutines + Play Tasks interop
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    // Firebase Cloud Messaging — needed by WiTalkFCMService.kt
    implementation("com.google.firebase:firebase-messaging-ktx:24.1.1")
}

flutter {
    source = "../.."
}
