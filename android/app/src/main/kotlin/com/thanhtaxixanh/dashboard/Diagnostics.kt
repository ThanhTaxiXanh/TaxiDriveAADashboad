package com.thanhtaxixanh.dashboard

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject
import org.json.JSONArray

// Main-thread only. Fixed, technical fields: never accepts free-form Dart logs.
class Diagnostics(context: Context) {
    private val prefs = context.getSharedPreferences("dashboard", Context.MODE_PRIVATE)
    private val file = File(context.filesDir, "diagnostics.txt")
    private val listeners = mutableSetOf<EventChannel.EventSink>()
    val values = mutableMapOf<String, Any>(
        "surface" to false, "firstFrame" to false, "touches" to 0, "fps" to 0.0,
        "layout" to (prefs.getString("layout", "{}") ?: "{}"), "panel" to "dashboard"
    )
    fun update(vararg entries: Pair<String, Any>) {
        values.putAll(entries)
        if (file.length() > 256 * 1024) file.writeText("")
        // Only aggregate diagnostic metrics, no coordinates or personal data.
        file.appendText("${System.currentTimeMillis()} ${entries.toMap()}\n")
        listeners.toList().forEach { it.success(HashMap(values)) }
    }
    fun saveLayout(input: Map<String, Any>) {
        fun number(key: String, min: Double, max: Double): Double {
            val value = (input[key] as? Number)?.toDouble() ?: error("Missing $key")
            require(value.isFinite() && value in min..max)
            return value
        }
        val weights = input["rowWeights"] as? List<*> ?: error("Missing weights")
        val enabled = input["rowEnabled"] as? List<*> ?: error("Missing enabled")
        require(weights.size == 3 && enabled.size == 3)
        require(weights.all { it is Number && it.toDouble().isFinite() && it.toDouble() in .1..10.0 })
        require(enabled.all { it is Boolean })
        val theme = input["theme"] as? String ?: error("Missing theme")
        require(theme in listOf("auto", "light", "dark"))
        val json = JSONObject().put("leftFraction", number("leftFraction", .4, .75))
            .put("rowWeights", JSONArray(weights)).put("rowEnabled", JSONArray(enabled))
            .put("theme", theme).put("fontScale", number("fontScale", .8, 1.6)).toString()
        prefs.edit().putString("layout", json).apply()
        update("layout" to json)
    }
    fun add(sink: EventChannel.EventSink) { listeners.add(sink); sink.success(HashMap(values)) }
    fun remove(sink: EventChannel.EventSink?) { listeners.remove(sink) }
    fun export(): String = "Taxi Xanh / phase 1\n$values\n" + if (file.exists()) file.readText() else ""
}

class DashboardBridge(engine: FlutterEngine, private val state: Diagnostics, share: (() -> Unit)? = null) {
    private val methods = MethodChannel(engine.dartExecutor.binaryMessenger, "taxi/dashboard")
    private val events = EventChannel(engine.dartExecutor.binaryMessenger, "taxi/dashboard/events")
    private var sink: EventChannel.EventSink? = null
    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "saveLayout" -> {
                    try {
                        state.saveLayout(call.argument<Map<String, Any>>("layout") ?: error("Missing layout"))
                        result.success(null)
                    } catch (e: Exception) { result.error("INVALID_LAYOUT", "Cấu hình không hợp lệ", null) }
                }
                "showPanel" -> {
                    val panel = call.argument<String>("panel")
                    if (panel in listOf("dashboard", "settings", "youtube", "modules")) {
                        state.update("panel" to panel!!); result.success(null)
                    } else result.error("INVALID_PANEL", "Không có bảng này", null)
                }
                "snapshot" -> result.success(HashMap(state.values))
                "frames" -> {
                    val frames = call.argument<Number>("frames")?.toDouble() ?: 0.0
                    val elapsed = call.argument<Number>("elapsedMs")?.toDouble() ?: 0.0
                    state.update("fps" to if (elapsed > 0) frames * 1000 / elapsed else 0.0)
                    result.success(null)
                }
                "shareLog" -> {
                    try {
                        if (share == null) result.error("PHONE_ONLY", "Chia sẻ trên điện thoại", null)
                        else { share(); result.success(null) }
                    } catch (e: Exception) { result.error("SHARE_FAILED", e.javaClass.simpleName, null) }
                }
                else -> result.notImplemented()
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                state.remove(sink); sink = events; state.add(events)
            }
            override fun onCancel(arguments: Any?) { state.remove(sink); sink = null }
        })
    }
    fun close() {
        state.remove(sink); sink = null
        methods.setMethodCallHandler(null); events.setStreamHandler(null)
    }
}
