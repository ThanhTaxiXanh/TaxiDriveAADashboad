package com.thanhtaxixanh.dashboard

import android.content.Context
import android.content.Intent
import android.location.Location
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

// Private state channel. Never put positions, names, routes or search results
// in the technical Diagnostics channel or exported log.
class NavigationState(private val context: Context) {
    private val prefs = context.getSharedPreferences("navigation", Context.MODE_PRIVATE)
    private val routeFile = File(context.filesDir, "navigation-route.json")
    private val listeners = mutableSetOf<EventChannel.EventSink>()
    private val handler = Handler(Looper.getMainLooper())
    var running = false
    var active = false
    var fix: Location? = null
    var status = "Bật vị trí trên điện thoại"
    var routeRevision = if (routeFile.exists()) 1L else 0L
    var goalRevision = 0L
    var goal: JSONObject? = prefs.getString("goal", null)?.let { JSONObject(it) }
    var places = JSONArray(prefs.getString("places", "[]"))
    var settings = JSONObject(prefs.getString("settings", "{}"))
    private var lease: String? = null
    private var leaseUntil = 0L
    private var nextRouteAt = 0L
    private var gesture = 0L
    private var scale = 1.0
    private var tts: TextToSpeech? = null
    private var voiceReady = false
    private val spoken = mutableSetOf<String>()
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK).setAudioAttributes(attributes).setOnAudioFocusChangeListener { change -> if (change == AudioManager.AUDIOFOCUS_LOSS) tts?.stop() }.build()
    fun snapshot(): String {
        val data = JSONObject().put("running", running).put("active", active).put("status", status)
            .put("goal", goal ?: JSONObject.NULL).put("places", places).put("settings", settings)
            .put("routeRevision", routeRevision).put("goalRevision", goalRevision)
            .put("voiceReady", voiceReady).put("gesture", gesture).put("scale", scale)
        fix?.let { p ->
            data.put("fix", JSONObject().put("lat", p.latitude).put("lon", p.longitude).put("accuracy", p.accuracy.toDouble())
                .put("speed", if (p.hasSpeed()) p.speed.coerceAtLeast(0f).toDouble() else 0.0)
                .put("bearing", if (p.hasBearing()) p.bearing.toDouble() else -1.0).put("time", p.time))
        }
        return data.toString()
    }
    fun emit() { val data = snapshot(); listeners.toList().forEach { it.success(data) } }
    fun add(sink: EventChannel.EventSink) { listeners.add(sink); sink.success(snapshot()) }
    fun remove(sink: EventChannel.EventSink?) { listeners.remove(sink) }
    fun location(value: Location) {
        if (!value.latitude.isFinite() || !value.longitude.isFinite() || !value.accuracy.isFinite() || value.accuracy < 0 || value.latitude !in -90.0..90.0 || value.longitude !in -180.0..180.0) return
        if (SystemClock.elapsedRealtimeNanos() - value.elapsedRealtimeNanos > 15_000_000_000L) return
        val old = fix
        if (old != null && value.elapsedRealtimeNanos <= old.elapsedRealtimeNanos) return
        if (old != null && value.elapsedRealtimeNanos - old.elapsedRealtimeNanos < 800_000_000L && value.accuracy >= old.accuracy) return
        fix = Location(value)
        emit()
    }
    fun place(raw: String): JSONObject {
        val p = JSONObject(raw)
        val lat = p.getDouble("lat"); val lon = p.getDouble("lon")
        require(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0)
        val name = p.getString("name").trim(); require(name.isNotEmpty() && name.length <= 150)
        return JSONObject().put("name", name).put("lat", lat).put("lon", lon).put("favorite", p.optBoolean("favorite", false))
    }
    private fun key(p: JSONObject) = String.format(Locale.US, "%.6f,%.6f", p.getDouble("lat"), p.getDouble("lon"))
    fun savePlace(p: JSONObject, remove: Boolean = false) {
        val next = JSONArray()
        if (!remove) next.put(p)
        for (i in 0 until places.length()) {
            val item = places.getJSONObject(i)
            if (key(item) != key(p) && next.length() < 40) next.put(item)
        }
        places = next; prefs.edit().putString("places", places.toString()).apply(); emit()
    }
    fun destination(p: JSONObject) {
        require(running) { "Enable location on phone" }
        // Preserve a favorite when selecting it from recent places.
        for (i in 0 until places.length()) if (key(places.getJSONObject(i)) == key(p) && places.getJSONObject(i).optBoolean("favorite")) p.put("favorite", true)
        goal = p; active = true; goalRevision++; routeFile.delete(); routeRevision++
        lease = null; leaseUntil = 0; spoken.clear(); status = "Đang chờ GPS để tìm đường"
        prefs.edit().putString("goal", p.toString()).apply(); savePlace(p)
    }
    fun stop(arrived: Boolean = false) {
        active = false; goalRevision++; lease = null; leaseUntil = 0
        if (!arrived) { routeFile.delete(); routeRevision++ }
        status = if (arrived) "Đã đến nơi" else "Đã dừng dẫn đường"
        tts?.stop(); audio.abandonAudioFocusRequest(focus); emit()
    }
    fun claim(revision: Long): String? {
        val now = SystemClock.elapsedRealtime()
        if (!running || !active || revision != goalRevision || now < nextRouteAt || now < leaseUntil) return null
        val age = fix?.let { now - it.elapsedRealtimeNanos / 1_000_000L } ?: Long.MAX_VALUE
        if (age > 10000 || (fix?.accuracy ?: Float.MAX_VALUE) > 50) return null
        lease = UUID.randomUUID().toString(); leaseUntil = now + 45000; nextRouteAt = now + 5000
        status = "Đang tìm đường"; emit(); return lease
    }
    fun route(raw: String?, token: String, revision: Long) {
        if (token != lease || revision != goalRevision || !active) return
        lease = null; leaseUntil = 0
        if (raw == null) {
            nextRouteAt = SystemClock.elapsedRealtime() + 30000
            status = "Chưa tìm được đường; sẽ thử lại khi có mạng"
        } else {
            require(raw.length <= 3 * 1024 * 1024)
            val parsed = JSONObject(raw); require(parsed.getJSONArray("points").length() in 2..100000)
            val temp = File(context.filesDir, "navigation-route.tmp")
            temp.writeText(raw); check(temp.renameTo(routeFile))
            routeRevision++; spoken.clear(); status = "Đang dẫn đường"
        }
        emit()
    }
    fun searchCache(): String = prefs.getString("searchCache", "{}") ?: "{}"
    fun searchCache(raw: String) {
        require(raw.length <= 1024 * 1024 && JSONObject(raw).length() <= 64)
        prefs.edit().putString("searchCache", raw).apply()
    }
    fun readRoute(): String? = if (routeFile.exists()) routeFile.readText() else null
    fun saveSettings(raw: String) {
        val input = JSONObject(raw)
        val clean = JSONObject()
        for ((name, default) in listOf("valhalla" to "https://valhalla1.openstreetmap.de/route", "osrm" to "https://routing.openstreetmap.de/routed-car/route/v1/driving", "photon" to "https://photon.komoot.io/api/")) {
            val value = input.optString(name, default)
            val uri = android.net.Uri.parse(value)
            require(value.length <= 300 && uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null && uri.query == null && uri.fragment == null)
            clean.put(name, value)
        }
        clean.put("voice", input.optBoolean("voice", true)).put("headingUp", input.optBoolean("headingUp", true))
        settings = clean; prefs.edit().putString("settings", settings.toString()).apply()
        if (!settings.optBoolean("voice", true)) { tts?.stop(); audio.abandonAudioFocusRequest(focus) }
        emit()
    }
    fun scale(factor: Double) { if (factor.isFinite() && factor > 0) { scale = factor.coerceIn(.5, 2.0); gesture++; emit() } }
    fun initSpeech() {
        if (tts != null) return
        tts = TextToSpeech(context) { result -> handler.post {
            val engine = tts ?: return@post
            if (result == TextToSpeech.SUCCESS) {
                val voice = engine.voices?.firstOrNull { it.locale.language == "vi" && !it.isNetworkConnectionRequired && !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) }
                if (voice != null) { engine.voice = voice; engine.setAudioAttributes(attributes); engine.setSpeechRate(.95f); voiceReady = true }
                engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) {}
                    override fun onDone(id: String?) { handler.post { audio.abandonAudioFocusRequest(focus) } }
                    @Deprecated("Legacy callback") override fun onError(id: String?) { handler.post { audio.abandonAudioFocusRequest(focus) } }
                })
            }
            emit()
        } }
    }
    fun speak(text: String, id: String, revision: Long) {
        if (!active || !running || !voiceReady || !settings.optBoolean("voice", true) || revision != routeRevision || text.length > 600 || id.length > 100 || id in spoken) return
        if (audio.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return
        spoken.add(id)
        if (spoken.size > 1000) spoken.clear()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, id)
    }
}

class NavigationBridge(engine: FlutterEngine, private val state: NavigationState, private val context: Context, private val phone: Boolean) {
    private val methods = MethodChannel(engine.dartExecutor.binaryMessenger, "taxi/navigation")
    private val events = EventChannel(engine.dartExecutor.binaryMessenger, "taxi/navigation/events")
    private var sink: EventChannel.EventSink? = null
    init {
        methods.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getSearchCache" -> { require(phone); result.success(state.searchCache()) }
                    "saveSearchCache" -> { require(phone); state.searchCache(call.argument<String>("json")!!); result.success(null) }
                    "snapshot" -> result.success(state.snapshot())
                    "getRoute" -> result.success(state.readRoute())
                    "destination" -> { state.destination(state.place(call.argument<String>("place")!!)); result.success(null) }
                    "stop" -> { state.stop(); result.success(null) }
                    "arrived" -> { state.stop(true); result.success(null) }
                    "stopLocation" -> { context.stopService(Intent(context, NavigationLocationService::class.java)); result.success(null) }
                    "claimRoute" -> result.success(state.claim(call.argument<Number>("revision")!!.toLong()))
                    "setRoute", "routeFailure" -> { state.route(if (call.method == "setRoute") call.argument<String>("route")!! else null, call.argument<String>("lease")!!, call.argument<Number>("revision")!!.toLong()); result.success(null) }
                    "speak" -> { state.speak(call.argument<String>("text")!!, call.argument<String>("id")!!, call.argument<Number>("revision")!!.toLong()); result.success(null) }
                    "savePlace", "removePlace", "saveSettings" -> {
                        require(phone)
                        if (call.method == "saveSettings") state.saveSettings(call.argument<String>("json")!!)
                        else state.savePlace(state.place(call.argument<String>("place")!!), call.method == "removePlace")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("NAVIGATION", "Không thực hiện được thao tác bản đồ; hãy kiểm tra vị trí/cài đặt trên điện thoại", null) }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { state.remove(sink); sink = events; state.add(events) }
            override fun onCancel(arguments: Any?) { state.remove(sink); sink = null }
        })
    }
    fun close() { state.remove(sink); methods.setMethodCallHandler(null); events.setStreamHandler(null) }
}
