// Top-level build file
plugins {
    id("com.android.application") version "8.9.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Chaquopy 17.0 (2025-12-01) is the version that actually added AGP 8.9-8.13
    // support. Anything older (like 16.x) calls a Gradle-internal class that's
    // being removed in Gradle 9, which is what caused the VersionNumber crash.
    id("com.chaquo.python") version "17.0.0" apply false
}
