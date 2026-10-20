import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key để ký bản phát hành lên CH Play.
//
// Hai nguồn, ưu tiên theo thứ tự:
//   1. Biến môi trường Codemagic (CM_KEYSTORE_PATH…) — có khi workflow khai
//      `android_signing` trỏ tới keystore đã nạp ở Team settings > Code signing.
//   2. android/key.properties trên máy dev (đã nằm trong .gitignore).
// Không có nguồn nào thì bản release rơi về khoá debug: build chạy được để thử,
// nhưng CH Play sẽ từ chối file đó.
//
// Đây là UPLOAD key, không phải app signing key: Play App Signing giữ khoá ký
// thật ở phía Google. Mất upload key thì xin Google reset được, khác với mất
// khoá ký.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}
val releaseStoreFile: String? =
    System.getenv("CM_KEYSTORE_PATH") ?: keystoreProperties.getProperty("storeFile")

android {
    // Trùng bundle id bên iOS. Tên cũ app.workreflection.workreflection_mobile
    // chưa từng lên CH Play, nên đổi lúc này không mất gì; sau khi tải AAB đầu
    // tiên thì tên này khoá vĩnh viễn.
    namespace = "app.workreflection.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.workreflection.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                    ?: keystoreProperties.getProperty("storePassword")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                    ?: keystoreProperties.getProperty("keyAlias")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
                    ?: keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// Google Play bắt buộc thư viện native căn trang 16 KB (targetSdk 35+).
// mobile_scanner 5.2.3 kéo ML Kit barcode-scanning 17.2.0 và CameraX 1.3.3,
// hai bản này còn căn 4 KB (libbarhopper_v3.so, libimage_processing_util_jni.so).
// Ép lên bản đã căn 16 KB ở đây thay vì nâng mobile_scanner 6.x, vì bản 6 kéo
// sàn iOS lên 15.5. Gradle chọn bản cao hơn nên code của plugin vẫn giữ nguyên.
dependencies {
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
}
