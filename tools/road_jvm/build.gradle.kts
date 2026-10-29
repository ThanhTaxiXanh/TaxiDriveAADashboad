plugins { kotlin("jvm") version "2.2.20" }
repositories { google(); mavenCentral() }
dependencies {
    implementation("androidx.sqlite:sqlite-bundled:2.7.1")
    testImplementation("junit:junit:4.13.2")
}
kotlin { jvmToolchain(17) }
sourceSets.main {
    kotlin.srcDir("../../android/app/src/main/kotlin")
    kotlin.include("**/RoadDatabase.kt")
    kotlin.include("**/MediaPolicy.kt")
}
tasks.test {
    environment("ROAD_FIXTURE", file("../../build/road-contract.sqlite").absolutePath)
    testLogging { events("passed", "failed", "skipped") }
}
