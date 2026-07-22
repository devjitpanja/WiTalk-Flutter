allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Prevent legacy plugins from introducing a second KGP version.
    // share_plus and similar plugins still declare KGP in their buildscript;
    // forcing a single version here avoids the multi-KGP compile error on AGP 9.
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.3.20")
            }
        }
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

// flutter_webrtc 0.12.12+hotfix.1 hard-codes compileSdkVersion 31 in its
// own build.gradle. It has been patched in the pub cache to use 36.
// No subproject override needed here.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
