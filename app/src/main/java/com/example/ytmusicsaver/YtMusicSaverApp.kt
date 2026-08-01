package com.example.ytmusicsaver

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class YtMusicSaverApp : Application() {

    override fun onCreate() {
        super.onCreate()

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        createNotificationChannel()
        UpdateManager.schedulePeriodicUpdateCheck(this)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Downloads",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress while saving audio from shared links"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    companion object {
        const val CHANNEL_ID = "downloads"
    }
}
