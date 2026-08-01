package com.example.ytmusicsaver

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

enum class DownloadState { RUNNING, DONE, FAILED }

data class DownloadRecord(
    val id: String = UUID.randomUUID().toString(),
    val url: String,
    val state: DownloadState,
    val detail: String = ""
)

/** Deliberately simple in-memory log — swap for a Room table if you want history to
 *  survive process death. */
object DownloadLog {
    private val _records = MutableStateFlow<List<DownloadRecord>>(emptyList())
    val records = _records.asStateFlow()

    fun start(url: String): String {
        val record = DownloadRecord(url = url, state = DownloadState.RUNNING, detail = "Starting…")
        _records.value = listOf(record) + _records.value
        return record.id
    }

    fun update(id: String, detail: String) {
        _records.value = _records.value.map {
            if (it.id == id) it.copy(detail = detail) else it
        }
    }

    fun finish(id: String, state: DownloadState, detail: String) {
        _records.value = _records.value.map {
            if (it.id == id) it.copy(state = state, detail = detail) else it
        }
    }
}
