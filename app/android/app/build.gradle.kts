plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStore = System.getenv("LIULIANG_KEYSTORE_FILE")
val releasePassword = System.getenv("LIULIANG_KEYSTORE_PASSWORD")
val releaseAlias = System.getenv("LIULIANG_KEY_ALIAS")
val releaseKeyPassword = System.getenv("LIULIANG_KEY_PASSWORD")
val releaseSigningAvailable = listOf(releaseStore, releasePassword, releaseAlias, releaseKeyPassword)
    .all { !it.isNullOrBlank() }
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } && !releaseSigningAvailable) {
    throw GradleException("Release signing is required. Set LIULIANG_KEYSTORE_FILE, LIULIANG_KEYSTORE_PASSWORD, LIULIANG_KEY_ALIAS and LIULIANG_KEY_PASSWORD.")
}

android {
    namespace = "cn.liuliang.liuliang_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.liuliang.liuliang_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    signingConfigs {
        if (releaseSigningAvailable) {
            create("distribution") {
                storeFile = file(releaseStore!!)
                storePassword = releasePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningAvailable) signingConfig = signingConfigs.getByName("distribution")
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

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.work:work-runtime:2.10.1")
}
