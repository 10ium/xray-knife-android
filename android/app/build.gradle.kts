import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // استفاده از پلاگین رسمی فلاتر
    id("dev.flutter.flutter-gradle-plugin")
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty("flutter.versionCode")
if (flutterVersionCode == null) {
    flutterVersionCode = "1"
}

def flutterVersionName = localProperties.getProperty("flutter.versionName")
if (flutterVersionName == null) {
    flutterVersionName = "1.0"
}

android {
    namespace = "com.example.xray_knife_android"
    
    // --- تغییر مهم اینجاست ---
    // افزایش نسخه کامپایل به 34 برای رفع خطای کتابخانه‌ها
    compileSdk = 34
    
    // حذف NDK اجباری تا گریدل خودش بهترین نسخه را دانلود کند
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
        // تارگت همچنان روی 28 می‌ماند تا خطای Permission Denied ندهد
        targetSdk = 28
        
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            // برای ساین کردن در محیط گیت‌هاب از کانفیگ دیباگ استفاده می‌کنیم
            signingConfig = signingConfigs.getByName("debug")
            minifyEnabled = false
            shrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // آپدیت نسخه کاتلین برای سازگاری بهتر
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.20")
}
