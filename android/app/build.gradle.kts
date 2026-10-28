plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}
val signing = java.util.Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signing.load(it) }
android {
    namespace = "com.thanhtaxixanh.dashboard"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    defaultConfig {
        applicationId = "com.thanhtaxixanh.dashboard"
        minSdk = 28
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    if (signingFile.exists()) {
        signingConfigs.create("personal") {
            storeFile = file(signing.getProperty("storeFile"))
            storePassword = signing.getProperty("storePassword")
            keyAlias = signing.getProperty("keyAlias")
            keyPassword = signing.getProperty("keyPassword")
        }
    }
    buildTypes {
        getByName("release") {
            if (signingFile.exists()) signingConfig = signingConfigs.getByName("personal")
        }
    }
}
flutter { source = "../.." }
dependencies {
    implementation("androidx.car.app:app-projected:1.7.0")
    implementation("androidx.core:core-ktx:1.16.0")
}
