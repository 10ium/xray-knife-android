import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // پلاگین مدرن فلاتر برای پروژه‌های جدید
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
    
    // حل مشکل کتابخانه‌های جدید (Datastore) با کامپایل روی نسخه 34
    compileSdk = 34
    
    // اجازه دهید فلاتر خودش بهترین نسخه NDK را انتخاب کند
    // ndkVersion = "..." 

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
        
        // --- نکته حیاتی ---
        // تارگت روی 28 قفل شد تا مشکل Permission Denied حل شود
        targetSdk = 28
        
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            // در محیط گیت‌هاب از کلید دیباگ برای امضا استفاده می‌کنیم
            signingConfig = signingConfigs.getByName("debug")
            
            // در کاتلین باید از isMinifyEnabled استفاده شود
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
