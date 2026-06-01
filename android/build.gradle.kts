import org.gradle.api.JavaVersion
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.configureEach {
        exclude(group = "com.android.support")
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
    pluginManager.withPlugin("com.android.library") {
        val android = extensions.findByName("android") ?: return@withPlugin
        try {
            val getNamespace = android.javaClass.getMethod("getNamespace")
            val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
            val currentNamespace = getNamespace.invoke(android) as String?
            if (currentNamespace.isNullOrBlank()) {
                val manifest = project.file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val packageRegex = Regex("""package="([^"]+)"""")
                    packageRegex.find(manifest.readText())?.groupValues?.getOrNull(1)?.let { pkg ->
                        setNamespace.invoke(android, pkg)
                    }
                } else {
                    val fallbackNamespace = project.group.toString()
                    if (fallbackNamespace.isNotBlank() && fallbackNamespace != "unspecified") {
                        setNamespace.invoke(android, fallbackNamespace)
                    }
                }
            }

            forceLegacyAndroidCompileSdk(android, 36)
        } catch (_: Exception) {
            // Ignore legacy plugin modules without the modern Android DSL.
        }
    }
}

subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            forceLegacyAndroidCompileSdk(android, 36)
            forceLegacyAndroidJavaTarget(android, JavaVersion.VERSION_17)
            if (pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
                forceLegacyAndroidKotlinJvmTarget(android, "17")
            }
        }

        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

subprojects {
    if (name == "firebase_storage") {
        pluginManager.withPlugin("com.android.library") {
            if (!pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
                pluginManager.apply("org.jetbrains.kotlin.android")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

fun forceLegacyAndroidJavaTarget(android: Any, javaVersion: JavaVersion) {
    try {
        val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
        compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
            .invoke(compileOptions, javaVersion)
        compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
            .invoke(compileOptions, javaVersion)
    } catch (_: Exception) {
        // Plugin uses a DSL this project does not recognize.
    }
}

fun forceLegacyAndroidKotlinJvmTarget(android: Any, kotlinJvmTarget: String) {
    try {
        val kotlinOptions = android.javaClass.getMethod("getKotlinOptions").invoke(android)
        kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
            .invoke(kotlinOptions, kotlinJvmTarget)
    } catch (_: Exception) {
        // Plugin uses a DSL this project does not recognize.
    }
}

fun forceLegacyAndroidCompileSdk(android: Any, compileSdk: Int) {
    try {
        android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
            .invoke(android, compileSdk)
        return
    } catch (_: Exception) {
        // Fall through to newer AGP APIs.
    }

    try {
        android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
            .invoke(android, compileSdk)
        return
    } catch (_: Exception) {
        // Fall through to AGP 8+ property setter.
    }

    try {
        android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
            .invoke(android, compileSdk)
    } catch (_: Exception) {
        // Plugin uses a DSL this project does not recognize.
    }
}
