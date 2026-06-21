buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// printing 5.13.x declares compileSdkVersion 30, but Material ≥1.5.0 (pulled
// in transitively) references android:attr/lStar which was added in API 31,
// causing verifyReleaseResources to fail for APK builds.
// gradle.afterProject fires per-project after evaluation completes — safe with
// AGP 8.x eager project evaluation, unlike subprojects { afterEvaluate }.
gradle.afterProject {
    val android = extensions.findByName("android")
        as? com.android.build.gradle.BaseExtension ?: return@afterProject
    val sdk = android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull() ?: 0
    if (sdk in 1..30) android.compileSdkVersion(34)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}