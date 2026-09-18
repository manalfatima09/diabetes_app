plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
    // Remove this line from plugins:
    // id("com.google.gms.google-services")
}

android {
    namespace = "com.example.diabetes_care"
    compileSdk = 34
    ndkVersion = "23.1.7779620"

    defaultConfig {
        applicationId = "com.example.diabetes_care"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}

// ✅ Apply Google Services plugin this way for Kotlin DSL
apply(plugin = "com.google.gms.google-services")
