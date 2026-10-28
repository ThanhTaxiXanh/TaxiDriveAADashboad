package com.thanhtaxixanh.dashboard

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Main-thread only. Fixed, technical fields: never accepts free-form Dart logs.
class Diagnostics(context: Context) {
    private val file = File(context.filesDir, "diagnostics.txt")
    private val listeners = mutableSetOf<EventChannel.EventSink>()
    val values = mutableMapOf<String, Any>(
        "surface" to false, "firstFrame" to false, "touches" to 0, "fps" to 0.0
    )
    fun update(vararg entries: Pair<String, Any>) {
        values.putAll(entries)
        if (file.length() > 256 * 1024) file.writeText("")
        // Only aggregate diagnostic metrics, no coordinates or personal data.
        file.appendText("${System.currentTimeMillis()} ${entries.toMap()}\n")
        listeners.toList().forEach { it.success(HashMap(values)) }
    }
    fun add(sink: EventChannel.EventSink) { listeners.add(sink); sink.success(HashMap(values)) }
    fun remove(sink: EventChannel.EventSink?) { listeners.remove(sink) }
    fun export(): String = "Taxi Xanh / phase 0\n$values\n" + if (file.exists()) file.readText() else ""
}

class DashboardBridge(engine: FlutterEngine, private val state: Diagnostics, share: (() -> Unit)? = null) {
    private val methods = MethodChannel(engine.dartExecutor.binaryMessenger, "taxi/dashboard")
    private val events = EventChannel(engine.dartExecutor.binaryMessenger, "taxi/dashboard/events")
    private var sink: EventChannel.EventSink? = null
    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
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
