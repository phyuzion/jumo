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
        minSdk = 24
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
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = false

            // ProGuard/R8 설정 추가
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), 
                "proguard-rules.pro"
            )
        }
        // getByName("debug") { isMinifyEnabled = false } // 디버그 빌드는 보통 비활성화
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 예) 다른 의존성들
    // implementation("androidx.core:core-ktx:1.9.0")
    // ...

    // Google Play Core 라이브러리 (앱 분할 설치 및 동적 기능 모듈)
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.play:core-ktx:1.8.1")

    // AppCompat 라이브러리 (커버 화면 액티비티용)
    implementation("androidx.appcompat:appcompat:1.6.1")


    // core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
