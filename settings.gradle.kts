// This block is used for configuring how plugins are resolved for the entire project.
// It's standard for Flutter projects.
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        // Load flutter.sdk path from local.properties
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        // Ensure flutter.sdk is set, otherwise throw an error.
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    // Include the Flutter Gradle build logic.
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Define repositories where Gradle should search for plugins.
    repositories {
        google()            // Google's Maven repository for Android and Firebase plugins.
        mavenCentral()      // Maven Central repository for general plugins.
        gradlePluginPortal() // The Gradle Plugin Portal for various Gradle plugins.
    }

    // Configure dependency resolution for plugin artifacts.
    dependencyResolutionManagement {
        repositories {
            google()
            mavenCentral()
        }
    }
}

// This block explicitly declares plugins used in the project.
// `apply false` means these plugins are only declared here and
// are actually applied in the respective module's build.gradle.kts file (e.g., app/build.gradle.kts).
plugins {
    // Declares the Flutter Gradle Plugin Loader.
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Declares the Android Application Gradle Plugin.
    id("com.android.application") version "8.7.0" apply false // Use a compatible Android Gradle Plugin version
    // Declares the Kotlin Android Gradle Plugin.
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false // Use a compatible Kotlin Gradle Plugin version
    // If you were to add Firebase later, its plugin would be declared here:
    // id("com.google.gms.google-services") version "4.4.2" apply false
}
rootProject.name = "vitalyz"
// This line includes your main application module into the Gradle build.
include(":app")
