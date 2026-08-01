package com.example.ytmusicsaver

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.Toast

class ShareReceiverActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val url = extractUrl(sharedText())

        if (url == null) {
            Toast.makeText(this, "Couldn't find a link in what was shared", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        val serviceIntent = Intent(this, DownloadService::class.java).apply {
            action = DownloadService.ACTION_DOWNLOAD
            putExtra(DownloadService.EXTRA_URL, url)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        Toast.makeText(this, "Saving to Music…", Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun sharedText(): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else null

    private fun extractUrl(text: String?): String? =
        text?.let { Regex("""https?://\S+""").find(it)?.value }
}
