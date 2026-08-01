package com.example.ytmusicsaver

import android.content.Context
import java.io.File

/**
 * Binaries placed in app/src/main/jniLibs/<abi>/lib*.so get installed by the OS into
 * applicationInfo.nativeLibraryDir, which — unlike app-writable storage such as filesDir
 * or cacheDir — is NOT mounted noexec. That's what lets us fork+exec real ELF binaries
 * (ffmpeg, a Bionic-compiled node CLI) on Android 10+ without hitting EACCES.
 *
 * See README.md "Native binaries" for where to obtain libffmpeg.so / libnodejs.so.
 */
object NativeBinaries {

    fun ffmpegPath(context: Context): String? =
        resolve(context, "libffmpeg.so")

    fun nodePath(context: Context): String? =
        resolve(context, "libnodejs.so")

    private fun resolve(context: Context, soName: String): String? {
        val dir = context.applicationInfo.nativeLibraryDir ?: return null
        val file = File(dir, soName)
        return if (file.exists() && file.canExecute()) file.absolutePath else null
    }
}
