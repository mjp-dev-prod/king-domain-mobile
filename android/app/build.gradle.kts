plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kingdomain.king_domain"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kingdomain.king_domain"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Two apps from one codebase (docs.flutter.dev/deployment/flavors).
    // production keeps the original application ID, so installed copies keep
    // updating. staging gets its own ID and name, so Android treats it as a
    // separate app that installs next to production, never over it.
    flavorDimensions += "environment"
    productFlavors {
        create("production") {
            dimension = "environment"
            resValue(type = "string", name = "app_name", value = "King Domain")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue(type = "string", name = "app_name", value = "KD Staging")
        }
    }

    // A permanent signing key for builds that are given one (Codemagic passes it
    // in through these CM_KEYSTORE_* variables when a workflow lists
    // `android_signing`: docs.codemagic.io/yaml-code-signing/signing-android).
    // Without one, every CI build makes a fresh random debug key, and Android
    // refuses to install a build over an app signed with a different key. It
    // reports that as "App not installed as package appears to be invalid".
    val ciKeystorePath: String? = System.getenv("CM_KEYSTORE_PATH")
    signingConfigs {
        create("kdRelease") {
            if (ciKeystorePath != null) {
                storeFile = file(ciKeystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Debug keys when no permanent key is supplied, so a local
            // `flutter run --release` still works.
            signingConfig = if (ciKeystorePath != null) {
                signingConfigs.getByName("kdRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
