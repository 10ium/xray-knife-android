def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

android {
    namespace "com.example.xray_knife_android"
    // استفاده از نسخه استاندارد برای کامپایل
    compileSdkVersion 33
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        // شناسه یکتای اپلیکیشن شما
        applicationId "com.example.xray_knife_android"
        
        // حداقل نسخه پشتیبانی شده (اندروید 5.0)
        minSdkVersion 21
        
        // --- نکته حیاتی برای دور زدن خطای Permission Denied در لینوکس ---
        // محدود کردن تارگت روی API 28 (اندروید 9) تا سیستم‌عامل اجازه اجرای فایل باینری دانلود شده را بدهد.
        targetSdkVersion 28
        
        // خواندن نسخه به صورت هوشمند از تنظیمات فلاتر
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            // امضای خودکار اپلیکیشن در محیط‌های بیلد (گیت‌هاب)
            signingConfig signingConfigs.debug
            // جلوگیری از فشرده‌سازی بیش از حد که ممکن است فایل‌های حساس را خراب کند
            minifyEnabled false
            shrinkResources false
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
}
