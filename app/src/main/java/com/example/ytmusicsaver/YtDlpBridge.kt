package com.example.ytmusicsaver

import android.content.Context
import com.chaquo.python.PyObject
import com.chaquo.python.Python

sealed class DownloadResult {
    data class Success(val filePath: String) : DownloadResult()
    data class Failure(val error: String) : DownloadResult()
}

object YtDlpBridge {

    private fun module(): PyObject = Python.getInstance().getModule("downloader")

    /**
     * Blocking call — run this from a background thread/coroutine, never the main thread.
     * `scratchDir` should be an app-private cache directory; DownloadService moves the
     * finished file into MediaStore afterwards (see MediaStoreSaver).
     */
    fun download(context: Context, url: String, scratchDir: String): DownloadResult {
        val ffmpeg = NativeBinaries.ffmpegPath(context)
            ?: return DownloadResult.Failure(
                "ffmpeg binary not found in nativeLibraryDir — see README 'Native binaries'"
            )
        val node = NativeBinaries.nodePath(context) // null is tolerated; yt-dlp falls back

        val result = module().callAttr(
            "download",
            url,
            scratchDir,
            ffmpeg,
            node,
            context.applicationInfo.nativeLibraryDir,
            null // cookies_file path, wire up later if you need age-restricted/private videos
        )

        val map = result.asMap()
        val ok = map[PyObject.fromJava("ok")]?.toBoolean() ?: false
        return if (ok) {
            val path = map[PyObject.fromJava("path")]?.toString()
                ?: return DownloadResult.Failure("yt-dlp reported success but no path")
            DownloadResult.Success(path)
        } else {
            val error = map[PyObject.fromJava("error")]?.toString() ?: "Unknown error"
            DownloadResult.Failure(error)
        }
    }

    fun installedVersion(): String =
        module().callAttr("get_installed_version").toString()
}
