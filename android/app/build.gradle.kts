plugins {
    id("com.android.application")
    // O plugin do Flutter Gradle deve ser aplicado após os plugins do Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.navegador_docx"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.navegador_docx"
        // Android 10 (API 29) é o mínimo para suporte a scoped storage
        minSdk = 29
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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
