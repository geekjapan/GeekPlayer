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
// (android-33) than the androidx libraries they depend on require (>= 34),
// which fails `checkDebugAarMetadata`. Force such plugin modules up to the
// app's SDK level. Reflection avoids needing the AGP classpath here.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val targetApi = 35
        runCatching {
            val current =
                android.javaClass.getMethod("getCompileSdkVersion").invoke(android)
                    as? String
            val currentApi = current?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (currentApi in 1 until targetApi) {
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
