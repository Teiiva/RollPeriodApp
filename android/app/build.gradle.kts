plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.marin.rollperiod"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.marin.rollperiod"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = 6
        versionName = "1.0.4"

        // ✅ Nécessaire pour MANAGE_EXTERNAL_STORAGE
        if (flutter.targetSdkVersion >= 30) {
            manifestPlaceholders["android.permission.MANAGE_EXTERNAL_STORAGE"] = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ❌ PAS besoin de coreLibraryDesugaring ici
