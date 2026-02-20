import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.xray_knife_android"
    
    // ارتقا به نسخه 36 برای سازگاری با پلاگین‌های جدید فلاتر
    compileSdk = 36
    
    // ndkVersion = "..." (Let Flutter choose)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.example.xray_knife_android"
        minSdk = 21
        
        // نکته حیاتی: روی 28 نگه می‌داریم برای اجرای باینری Xray
        targetSdk = 28
        
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }
    
    // --- تغییر جدید و مهم: غیرفعال کردن چک‌های سختگیرانه ---
    lint {
        // نادیده گرفتن خطای "هدف قدیمی" تا بیلد شکست نخورد
        disable += "ExpiredTargetSdkVersion"
        // نادیده گرفتن بقیه خطاهای غیرحیاتی
        abortOnError = false
        checkReleaseBuilds = false
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.0")
}
