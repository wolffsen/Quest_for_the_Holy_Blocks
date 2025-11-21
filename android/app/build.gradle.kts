import java.util.Locale
import java.util.Properties
import java.io.FileInputStream

val keystoreProps = Properties()
val keystorePropsFile = rootProject.file("key.properties") // points to android/key.properties
if (keystorePropsFile.exists()) {
    keystoreProps.load(FileInputStream(keystorePropsFile))
}

plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.spikeynorman.questfortheholyblocks"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.spikeynorman.questfortheholyblocks"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProps.isNotEmpty()) {
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

afterEvaluate {
    fun configureCopy(taskName: String, variant: String) {
        tasks.findByName(taskName)?.doLast {
            val sourceDir = file("$buildDir/outputs/apk/${variant.lowercase(Locale.US)}")
            if (!sourceDir.exists()) return@doLast
            val flutterRoot = rootProject.projectDir.parentFile
            val flutterBuildDir = flutterRoot
                ?.resolve("build/app/outputs/flutter-apk")
                ?.apply { mkdirs() }
                ?: return@doLast
            sourceDir.listFiles { file -> file.extension == "apk" }?.forEach { apk ->
                apk.copyTo(flutterBuildDir.resolve("app-$variant.apk"), overwrite = true)
            }
        }
    }
    configureCopy("assembleDebug", "debug")
    configureCopy("assembleRelease", "release")
}
