plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ravisahu.photoeditor"
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
        // Application ID - Change this to your unique package name for Play Store
        applicationId = "com.ravisahu.photoeditor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // IMPORTANT: For production, create a keystore.jks file and configure signing:
            // 1. Run: keytool -genkey -v -keystore ~/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
            // 2. Create a keystore.properties file (add to .gitignore):
            //    storePassword=your_password
            //    keyPassword=your_key_password
            //    keyAlias=key
            //    storeFile=/path/to/keystore.jks
            // 3. Uncomment signingConfigs section below
            // Signing with the debug keys for now - replace before Play Store release!
            signingConfig = signingConfigs.getByName("debug")

            // Enable code shrinking and obfuscation for release builds
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
}

flutter {
    source = "../.."
}
