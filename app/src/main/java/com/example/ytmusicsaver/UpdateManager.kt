package com.example.ytmusicsaver

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.chaquo.python.Python
import java.util.concurrent.TimeUnit

object UpdateManager {

    private const val WORK_NAME = "ytdlp-auto-update"

    fun schedulePeriodicUpdateCheck(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.UNMETERED) // yt-dlp[default] pulls a few MB; avoid mobile data by default
            .build()

        val request = PeriodicWorkRequestBuilder<UpdateWorker>(1, TimeUnit.DAYS)
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }

    /** Call directly for a manual "check now" button in Settings, off the main thread. */
    fun updateNow(context: Context): String {
        val targetDir = context.applicationContext.filesDir.absolutePath + "/chaquopy/AssetFinder/app"
        val module = Python.getInstance().getModule("updater")
        return module.callAttr("update_if_needed", targetDir).toString()
    }
}

class UpdateWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        return try {
            UpdateManager.updateNow(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
