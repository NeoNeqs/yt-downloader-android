package com.example.ytmusicsaver

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File

class DownloadService : Service() {

    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private var activeCount = 0

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val url = intent?.getStringExtra(EXTRA_URL)
        if (intent?.action == ACTION_DOWNLOAD && url != null) {
            startForeground(NOTIFICATION_ID, buildNotification("Saving audio…"))
            runDownload(url)
        }
        return START_NOT_STICKY
    }

    private fun runDownload(url: String) {
        activeCount++
        val recordId = DownloadLog.start(url)

        scope.launch {
            val scratchDir = File(cacheDir, "ytdlp_scratch").apply { mkdirs() }

            val result = YtDlpBridge.download(this@DownloadService, url, scratchDir.absolutePath)

            when (result) {
                is DownloadResult.Success -> {
                    val sourceFile = File(result.filePath)
                    val saved = MediaStoreSaver.saveAudio(
                        this@DownloadService,
                        sourceFile,
                        sourceFile.name
                    )
                    if (saved) {
                        DownloadLog.finish(recordId, DownloadState.DONE, "Saved to Music/YtMusicSaver")
                    } else {
                        DownloadLog.finish(recordId, DownloadState.FAILED, "Couldn't write to Music library")
                    }
                }
                is DownloadResult.Failure -> {
                    DownloadLog.finish(recordId, DownloadState.FAILED, result.error)
                }
            }

            activeCount--
            if (activeCount <= 0) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    private fun buildNotification(text: String): Notification =
        NotificationCompat.Builder(this, YtMusicSaverApp.CHANNEL_ID)
            .setContentTitle("YtMusicSaver")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .build()

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_DOWNLOAD = "com.example.ytmusicsaver.action.DOWNLOAD"
        const val EXTRA_URL = "extra_url"
        private const val NOTIFICATION_ID = 42
    }
}
