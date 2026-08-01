package com.example.ytmusicsaver

import android.graphics.Color
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.example.ytmusicsaver.databinding.ItemDownloadBinding

class DownloadAdapter : RecyclerView.Adapter<DownloadAdapter.ViewHolder>() {

    private var items: List<DownloadRecord> = emptyList()

    fun submitList(newItems: List<DownloadRecord>) {
        items = newItems
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemDownloadBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount() = items.size

    class ViewHolder(private val binding: ItemDownloadBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(record: DownloadRecord) {
            binding.url.text = record.url
            binding.detail.text = record.detail
            binding.detail.setTextColor(
                when (record.state) {
                    DownloadState.RUNNING -> Color.parseColor("#FFA000")
                    DownloadState.DONE -> Color.parseColor("#2E7D32")
                    DownloadState.FAILED -> Color.parseColor("#C62828")
                }
            )
        }
    }
}
