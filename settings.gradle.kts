pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven("https://chaquo.com/maven") // Chaquopy (Python-in-Android) plugin repo
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://chaquo.com/maven")
    }
}

rootProject.name = "YtMusicSaver"
include(":app")
