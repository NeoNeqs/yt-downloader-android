package com.example.ytmusicsaver

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

object MediaStoreSaver {

    /**
     * Copies `sourceFile` (produced by yt-dlp in the app's private cache dir) into the
     * shared Music/YtMusicSaver folder so it shows up in other music apps, and deletes
     * the private scratch copy afterwards.
     *
     * No storage permission is required for this on API 29+: apps can always insert
     * new files into MediaStore collections they don't own, they just can't read/modify
     * files they didn't create without extra permission.
     */
    fun saveAudio(context: Context, sourceFile: File, displayName: String, mimeType: String = "audio/mpeg"): Boolean {
        val resolver = context.contentResolver

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
            put(MediaStore.Audio.Media.IS_MUSIC, 1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/YtMusicSaver")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val itemUri = resolver.insert(collection, values) ?: return false

        resolver.openOutputStream(itemUri)?.use { out ->
            sourceFile.inputStream().use { input -> input.copyTo(out) }
        } ?: return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)
        }

        sourceFile.delete()
        return true
    }
}
