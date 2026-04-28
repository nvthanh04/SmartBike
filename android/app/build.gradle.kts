plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Kích hoạt Google Services
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.smartbike"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.smartbike"
        // Thư viện Firebase yêu cầu tối thiểu là 23
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

dependencies {
    // Khai báo thư viện Firebase BOM để quản lý phiên bản
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
}

// Chốt hạ lệnh áp dụng plugin (phải dùng nháy kép và ngoặc đơn)
apply(plugin = "com.google.gms.google-services")
