plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jumo.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jumo.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // signingConfig = ...
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 예) 다른 의존성들
    // implementation("androidx.core:core-ktx:1.9.0")
    // ...

    // core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
