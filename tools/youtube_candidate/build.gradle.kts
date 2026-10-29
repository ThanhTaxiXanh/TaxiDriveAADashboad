import java.time.Duration
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    kotlin("jvm") version "2.2.20"
    application
}
repositories {
    mavenCentral()
    maven("https://jitpack.io") {
        content {
            includeGroup("com.github.teamnewpipe")
            includeGroup("com.github.TeamNewPipe")
        }
    }
}
dependencies {
    implementation("com.github.teamnewpipe:NewPipeExtractor:v0.26.5")
}
kotlin {
    jvmToolchain(17)
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}
application { mainClass.set("candidate.NewPipeSpikeKt") }
tasks.named<JavaExec>("run") {
    timeout.set(Duration.ofSeconds(100))
    jvmArgs("-Xmx384m")
}
