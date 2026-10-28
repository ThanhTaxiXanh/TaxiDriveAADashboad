package com.thanhtaxixanh.dashboard

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject
import org.json.JSONArray

// Main-thread only. Fixed, technical fields: never accepts free-form Dart logs.
class Diagnostics(val context: Context) {
    val payment by lazy { PaymentStorage(context.applicationContext) }
    val calendar by lazy { EventDatabase(context.applicationContext) }
    private val prefs = context.getSharedPreferences("dashboard", Context.MODE_PRIVATE)
    private val file = File(context.filesDir, "diagnostics.txt")
    private val listeners = mutableSetOf<EventChannel.EventSink>()
    val values = mutableMapOf<String, Any>(
        "surface" to false, "firstFrame" to false, "touches" to 0, "fps" to 0.0,
        "layout" to (prefs.getString("layout", "{}") ?: "{}"), "panel" to "dashboard", "calendarRevision" to 0L, "paymentRevision" to 0L
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
    fun calendarChanged() { update("calendarRevision" to ((values["calendarRevision"] as Long) + 1), "calendarError" to "Không") }
    fun add(sink: EventChannel.EventSink) { listeners.add(sink); sink.success(HashMap(values)) }
    fun remove(sink: EventChannel.EventSink?) { listeners.remove(sink) }
    fun export(): String = "Taxi Xanh / phase 4\n$values\n" + if (file.exists()) file.readText() else ""
}

class DashboardBridge(engine: FlutterEngine, private val state: Diagnostics, share: (() -> Unit)? = null) {
    private val methods = MethodChannel(engine.dartExecutor.binaryMessenger, "taxi/dashboard")
    private val events = EventChannel(engine.dartExecutor.binaryMessenger, "taxi/dashboard/events")
    private var sink: EventChannel.EventSink? = null
    private val navigation = NavigationBridge(engine, (state.context.applicationContext as DashboardApplication).navigation, state.context.applicationContext, share != null)
    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPayment" -> {
                    try { result.success(state.payment.read()) }
                    catch (e: Exception) { result.error("PAYMENT_READ", "Không đọc được QR", null) }
                }
                "getPaymentPickRole" -> result.success(state.payment.pendingRole())
                "savePayment", "writePaymentImage", "clearPayment", "setPaymentPickRole" -> {
                    if (share == null) result.error("PHONE_ONLY", "Chỉ cấu hình QR trên điện thoại", null)
                    else try {
                        when (call.method) {
                            "writePaymentImage" -> result.success(state.payment.writeImage(call.argument<ByteArray>("bytes") ?: error("Missing image")))
                            "setPaymentPickRole" -> { state.payment.pendingRole(call.argument<String>("role")); result.success(null) }
                            else -> {
                                if (call.method == "clearPayment") state.payment.clear()
                                else state.payment.save(call.argument<String>("json") ?: error("Missing config"))
                                state.update("paymentRevision" to ((state.values["paymentRevision"] as Long) + 1))
                                result.success(null)
                            }
                        }
                    } catch (e: Exception) { result.error("PAYMENT_WRITE", "Không lưu được QR hoặc ảnh không hợp lệ", null) }
                }
                "getCalendar" -> {
                    try { result.success(state.calendar.archive()) }
                    catch (e: Exception) { state.update("calendarError" to e.javaClass.simpleName); result.error("CALENDAR_READ", "Không đọc được lịch", null) }
                }
                "saveEvent", "toggleEvent", "deleteEvent", "setMonthly", "importCalendar" -> {
                    if (share == null) result.error("PHONE_ONLY", "Chỉ sửa sự kiện trên điện thoại", null)
                    else try {
                        when (call.method) {
                            "saveEvent" -> state.calendar.save(call.argument<String>("event") ?: error("Missing event"))
                            "toggleEvent" -> state.calendar.toggle(call.argument<String>("id") ?: error("Missing id"), call.argument<Boolean>("enabled") ?: error("Missing enabled"))
                            "deleteEvent" -> state.calendar.delete(call.argument<String>("id") ?: error("Missing id"))
                            "setMonthly" -> state.calendar.monthly(call.argument<Boolean>("enabled") ?: error("Missing enabled"))
                            "importCalendar" -> state.calendar.importArchive(call.argument<String>("json") ?: error("Missing JSON"))
                        }
                        state.calendarChanged(); result.success(null)
                    } catch (e: Exception) { state.update("calendarError" to e.javaClass.simpleName); result.error("CALENDAR_WRITE", "Không lưu được; dữ liệu hoặc ngày không hợp lệ", null) }
                }
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
        navigation.close()
        state.remove(sink); sink = null
        methods.setMethodCallHandler(null); events.setStreamHandler(null)
    }
}
