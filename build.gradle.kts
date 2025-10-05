allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Corrected Kotlin DSL syntax for classpath declarations
        classpath("com.android.tools.build:gradle:8.4.1") // Change from 7.3.0 to 8.1.0
        classpath("com.google.gms:google-services:4.4.1") // Keep this version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
    }
}
