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

    // ─────────────────────────────────────────────────────────────
    //  signingConfigs{} - Kotlin DSL
    // ─────────────────────────────────────────────────────────────
    signingConfigs {
        // release( ... ) -> 일반 Groovy DSL, KTS에서는 create("release") 또는 named("release")
        create("release") {
            // gradle.properties 등에서 변수를 불러온다고 가정
            // ex) MY_KEYSTORE=... , MY_KEY_ALIAS=... , etc.
            storeFile = file(
                project.findProperty("MY_KEYSTORE") ?: "../app/my-release-key.jks"
            )
            storePassword = project.findProperty("MY_KEYSTORE_PASSWORD")?.toString() ?: ""
            keyAlias = project.findProperty("MY_KEY_ALIAS")?.toString() ?: "key"
            keyPassword = project.findProperty("MY_KEY_ALIAS_PASSWORD")?.toString() ?: ""
        }
    }

    buildTypes {
        
        // getByName("release")로 가져와서 설정
        getByName("release") {
            // signingConfigs["release"] 가능, or signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("release")

        }
        // getByName("debug") { ... } // debug는 자동 서명
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
