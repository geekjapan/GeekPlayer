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

// Some plugins (e.g. onnxruntime) declare an older Android compileSdk
// (android-33) than the androidx libraries they depend on require, which
// fails `checkDebugAarMetadata`. Force such plugin modules up to the app's
// own compile SDK (derived from `flutter.compileSdkVersion`, not hard-coded)
// so they stay in lockstep when Flutter bumps the default. Reflection avoids
// needing the AGP classpath in this root build script.
fun Any.compileSdkApi(): Int? =
    (runCatching { javaClass.getMethod("getCompileSdkVersion").invoke(this) as? String }
        .getOrNull())
        ?.removePrefix("android-")
        ?.toIntOrNull()

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        // :app is evaluated first (evaluationDependsOn above), so its compile
        // SDK is readable here; fall back to 36 if it cannot be resolved.
        val targetApi =
            rootProject.project(":app").extensions.findByName("android")?.compileSdkApi()
                ?: 36
        val currentApi = android.compileSdkApi() ?: 0
        if (currentApi in 1 until targetApi) {
            runCatching {
                android.javaClass
                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(android, targetApi)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
