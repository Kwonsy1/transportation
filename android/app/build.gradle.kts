plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 네이버 맵 API 키 설정 (Kotlin 문법)
val naverMapClientId = if (project.hasProperty("NAVER_MAP_CLIENT_ID")) {
    project.property("NAVER_MAP_CLIENT_ID") as String
} else {
    "jpj5i2bvdl"
}

android {
    namespace = "com.example.transportation"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.transportation"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23  // flutter_naver_map 최소 요구 버전 (23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            manifestPlaceholders["naverMapClientId"] = naverMapClientId
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            manifestPlaceholders["naverMapClientId"] = naverMapClientId
        }
    }
}

flutter {
    source = "../.."
}
