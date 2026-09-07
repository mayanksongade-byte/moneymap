allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// subprojects {
//     tasks.withType<JavaCompile>().configureEach {
//         sourceCompatibility = "17"
//         targetCompatibility = "17"
//     }
//     tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
//         kotlinOptions {
//             jvmTarget = "17"
//         }
//     }
// }

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
