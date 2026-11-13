import java.util.concurrent.TimeUnit

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter supplies target-platform for its standard per-ABI build commands.
// The same property controls local Filament AAR packaging, so no APK is ever
// manually unpacked or repackaged after Gradle produces it.
val targetAbi = when (providers.gradleProperty("target-platform").orNull) {
    "android-arm64" -> "arm64-v8a"
    "android-x64" -> "x86_64"
    "android-arm" -> "armeabi-v7a"
    else -> null // Standard universal build keeps all available ABIs.
}

android {
    namespace = "app.orbit.orbit_visual_lab"
    // Filament 1.79.0 AAR metadata requires API 37 at compile time.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion
    val orbitGitHash = try {
        val gitDir = project.rootDir.parentFile ?: project.rootDir
        val proc = ProcessBuilder("git", "rev-parse", "--short", "HEAD")
            .directory(gitDir)
            .redirectOutput(ProcessBuilder.Redirect.PIPE)
            .redirectError(ProcessBuilder.Redirect.PIPE)
            .start()
        proc.waitFor(4, TimeUnit.SECONDS)
        val text = proc.inputStream.bufferedReader().readText().trim()
        if (text.isNotEmpty() && text.length in 7..40) text else "6cc857e"
    } catch (_: Exception) {
        "6cc857e"
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.orbit.orbit_visual_lab"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "ORBIT_GIT_HASH", "\"$orbitGitHash\"")
        buildConfigField("String", "ORBIT_BUILD_FLAVOR", "\"premium-reliability\"")
        // Some x86_64 emulator release drivers report zero Impeller texture limits.
        manifestPlaceholders["enableImpeller"] = if (targetAbi == "x86_64") "false" else "true"
        ndk {
            if (targetAbi != null) abiFilters += targetAbi
        }
    }

    packaging {
        jniLibs {
            // Local Filament AARs contain several ABIs. Keep only the requested
            // target during the normal AGP package task; universal stays intact.
            if (targetAbi != null) {
                excludes += listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
                    .filter { it != targetAbi }
                    .map { "lib/$it/**" }
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Official Filament 1.79.0 release AARs. Keeping the runtime on the same
    // release as matc guarantees compatibility with the bundled v79 materials.
    implementation(files("libs/filament-v1.79.0-android.aar"))
    implementation(files("libs/filament-utils-v1.79.0-android.aar"))
    implementation(files("libs/gltfio-v1.79.0-android.aar"))
}

flutter {
    source = "../.."
}
