package com.thanhtaxixanh.dashboard

import android.content.Context
import android.graphics.BitmapFactory
import java.io.File
import java.util.UUID
import org.json.JSONObject

// Shared by both engines, accessed only on the platform main thread.
// Payment data never enters Diagnostics.values, logs, exports or network calls.
class PaymentStorage(context: Context) {
    private val folder = File(context.filesDir, "payment").apply { mkdirs() }
    private val prefs = context.getSharedPreferences("payment", Context.MODE_PRIVATE)
    private val pathKeys = listOf("originalPath", "centerPath", "brandPath", "renderedPath")
    fun read(): String = prefs.getString("config", "{}") ?: "{}"
    fun pendingRole(): String? = prefs.getString("pendingRole", null)
    fun pendingRole(role: String?) {
        require(role == null || role in listOf("original", "center", "brand"))
        check(prefs.edit().putString("pendingRole", role).commit())
    }
    fun writeImage(bytes: ByteArray): String {
        require(bytes.isNotEmpty() && bytes.size <= 8 * 1024 * 1024)
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        require(options.outWidth in 1..2048 && options.outHeight in 1..2048 && options.outMimeType == "image/png")
        val target = File(folder, "${UUID.randomUUID()}.png")
        val temporary = File(folder, "${target.name}.tmp")
        temporary.outputStream().use { it.write(bytes) }
        check(temporary.renameTo(target))
        return target.absolutePath
    }
    fun save(raw: String) {
        require(raw.length <= 16 * 1024)
        val input = JSONObject(raw)
        require(input.optString("mode") in listOf("image", "generated"))
        val clean = JSONObject()
        for (key in listOf("mode", "bin", "bankName", "account", "holder", "amount", "note", "payload")) {
            val text = input.optString(key, "")
            require(text.length <= if (key == "payload") 1024 else 150)
            clean.put(key, text)
        }
        for (key in pathKeys) {
            val path = input.optString(key, "")
            if (path.isNotEmpty()) {
                val file = File(path).canonicalFile
                require(file.parentFile == folder.canonicalFile && file.isFile && file.extension == "png")
            }
            clean.put(key, path)
        }
        clean.put("rebuild", input.optBoolean("rebuild", false))
        clean.put("hideAccount", input.optBoolean("hideAccount", false))
        val rendered = clean.getString("mode") == "generated" || clean.getBoolean("rebuild")
        require(clean.getString(if (rendered) "renderedPath" else "originalPath").isNotEmpty())
        check(prefs.edit().putString("config", clean.toString()).commit())
        val keep = pathKeys.map { clean.getString(it) }.toSet()
        folder.listFiles()?.filter { it.absolutePath !in keep }?.forEach { it.delete() }
    }
    fun clear() {
        check(prefs.edit().clear().commit())
        folder.listFiles()?.forEach { it.delete() }
    }
}
