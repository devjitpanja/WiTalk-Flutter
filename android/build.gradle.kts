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

// Force all subprojects to compile against SDK 36
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(36)
    }
    plugins.withId("com.android.application") {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(36)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
