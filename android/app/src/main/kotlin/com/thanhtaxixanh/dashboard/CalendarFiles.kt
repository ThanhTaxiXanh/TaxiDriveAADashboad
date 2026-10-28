package com.thanhtaxixanh.dashboard

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class CalendarFiles(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "taxi/calendar_files")
    private var pending: MethodChannel.Result? = null
    private val request = 7821
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "import" -> {
                        if (pending != null) result.error("BUSY", "Đang chọn tệp", null)
                        else {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "*/*"; addCategory(Intent.CATEGORY_OPENABLE) }
                            pending = result
                            try { activity.startActivityForResult(intent, request) }
                            catch (e: Exception) { pending = null; throw e }
                        }
                    }
                    "export" -> {
                        val json = call.argument<String>("json") ?: error("Missing JSON")
                        require(json.toByteArray().size <= 1024 * 1024)
                        val folder = File(activity.cacheDir, "shared-events").apply { mkdirs() }
                        val file = File(folder, "taxi-xanh-events.json").apply { writeText(json) }
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.logs", file)
                        val intent = Intent(Intent.ACTION_SEND).apply { type = "application/json"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                        activity.startActivity(Intent.createChooser(intent, "Xuất sự kiện · Chọn nơi lưu hoặc chia sẻ"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("FILE_ERROR", "Không mở được tệp hoặc hộp chia sẻ", null) }
        }
    }
    fun activityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != request) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK) { result.success(null); return true }
        try {
            val uri = data?.data ?: error("Missing file")
            val bytes = ByteArrayOutputStream()
            activity.contentResolver.openInputStream(uri)?.use { input ->
                val buffer = ByteArray(8192)
                while (true) { val count = input.read(buffer); if (count < 0) break; require(bytes.size() + count <= 1024 * 1024); bytes.write(buffer, 0, count) }
            } ?: error("Cannot read file")
            result.success(bytes.toString("UTF-8"))
        } catch (e: Exception) { result.error("INVALID_FILE", "Tệp không đọc được hoặc lớn hơn 1 MB", null) }
        return true
    }
    fun close() { pending?.success(null); pending = null; channel.setMethodCallHandler(null) }
}
