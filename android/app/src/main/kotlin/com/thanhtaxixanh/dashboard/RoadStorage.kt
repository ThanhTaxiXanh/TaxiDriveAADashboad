package com.thanhtaxixanh.dashboard

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.zip.GZIPInputStream
import kotlin.math.*

// Private application singleton: R-tree queries/downloads on one worker, never
// the UI thread. Device positions and user pins never enter technical logs.
class RoadStorage(private val context: Context) {
    private val prefs = context.getSharedPreferences("road-data", Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val downloader = Executors.newSingleThreadExecutor()
    private val file = File(context.filesDir, "vietnam-roads.sqlite")
    private var database: SQLiteDatabase? = null // worker only
    private val listeners = mutableSetOf<EventChannel.EventSink>()
    private var revision = prefs.getLong("revision", 0)
    private var pins = JSONArray(prefs.getString("pins", "[]"))
    private var settings = JSONObject(prefs.getString("settings", "{}"))
    private var info = if (file.exists()) JSONObject(prefs.getString("info", "{}")) else JSONObject()
    private var downloading = false
    private var message = if (file.exists()) "Đã có gói dữ liệu ngoại tuyến" else "Chưa tải gói dữ liệu đường"
    private var progress = 0
    private var lastBeep = -30000L
    fun snapshot(): String = JSONObject().put("revision", revision).put("pins", pins).put("settings", settings).put("pack", info)
        .put("downloading", downloading).put("message", message).put("progress", progress).toString()
    fun add(sink: EventChannel.EventSink) { listeners.add(sink); sink.success(snapshot()) }
    fun remove(sink: EventChannel.EventSink?) { listeners.remove(sink) }
    private fun emit() { val raw = snapshot(); listeners.toList().forEach { it.success(raw) } }
    private fun changed() { revision++; prefs.edit().putLong("revision", revision).apply(); emit() }
    private fun cleanPin(input: JSONObject): JSONObject {
        val id = input.getString("id"); require(id.matches(Regex("user_[A-Za-z0-9_-]{1,75}")))
        val kind = input.getString("kind"); require(kind in setOf("speed","camera","noEntry","noLeft","noRight","noUturn","noStraight","noStop","noPark","noCar","stop","giveWay","calming"))
        val lat = input.getDouble("lat"); val lon = input.getDouble("lon")
        require(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0)
        val note = input.optString("note", ""); require(note.length <= 200)
        val scope = input.optDouble("scope", 300.0); require(scope.isFinite() && scope in 50.0..2000.0)
        val result = JSONObject().put("id",id).put("kind",kind).put("lat",lat).put("lon",lon).put("source","user").put("note",note).put("scope",scope)
        if (kind == "speed") { val value = input.getDouble("value"); require(value.isFinite() && value == value.toInt().toDouble() && value in 1.0..150.0); result.put("value",value.toInt()) }
        if (!input.isNull("bearing") && input.has("bearing")) { val bearing=input.getDouble("bearing"); require(bearing.isFinite() && bearing >= 0 && bearing < 360); result.put("bearing",bearing) }
        if (!input.isNull("way") && input.has("way")) { val way=input.getLong("way"); val along=input.getDouble("along"); require(way>0 && along.isFinite() && along>=0); result.put("way",way).put("along",along) }
        return result
    }
    fun savePin(raw: String) {
        val clean=cleanPin(JSONObject(raw)); val next=JSONArray()
        for (i in 0 until pins.length()) if (pins.getJSONObject(i).getString("id") != clean.getString("id")) next.put(pins.getJSONObject(i))
        next.put(clean); replacePins(next)
    }
    fun deletePin(id: String) {
        val next=JSONArray(); for (i in 0 until pins.length()) if (pins.getJSONObject(i).getString("id") != id) next.put(pins.getJSONObject(i))
        replacePins(next)
    }
    private fun replacePins(next: JSONArray) {
        require(next.length()<=2000 && next.toString().toByteArray().size<=1024*1024)
        pins=next; prefs.edit().putString("pins",pins.toString()).apply(); changed()
    }
    fun importPins(raw: String) {
        require(raw.toByteArray().size<=1024*1024)
        val input=JSONObject(raw); require(input.getInt("schema")==1)
        val values=input.getJSONArray("pins"); require(values.length()<=2000)
        val next=JSONArray(); val ids=mutableSetOf<String>()
        for (i in 0 until values.length()) { val p=cleanPin(values.getJSONObject(i)); require(ids.add(p.getString("id"))); next.put(p) }
        replacePins(next)
    }
    fun exportPins(): String = JSONObject().put("schema",1).put("pins",pins).toString()
    fun saveSettings(raw: String) {
        val input=JSONObject(raw); val vehicle=input.optString("vehicle","car"); require(vehicle in setOf("car","heavy","bus","towing","special","quadPassenger","quadCargo"))
        val tolerance=input.optInt("tolerance",5); require(tolerance in 0..20)
        settings=JSONObject().put("vehicle",vehicle).put("tolerance",tolerance).put("enabled",input.optBoolean("enabled",true)).put("estimates",input.optBoolean("estimates",true)).put("beep",input.optBoolean("beep",false))
        prefs.edit().putString("settings",settings.toString()).apply(); changed()
    }
    private fun open(): SQLiteDatabase? {
        if (!file.exists()) return null
        if (database==null) database=SQLiteDatabase.openDatabase(file.path,null,SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS)
        return database
    }
    fun nearby(lat: Double, lon: Double, reply: (String?, String?) -> Unit) {
        require(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0)
        worker.execute {
            try {
                val db=open(); val roads=JSONArray(); val signs=JSONArray(); var urban=false; var truncated=false
                if (db!=null) {
                    fun query(table: String, radius: Double, limit: Int, payload: Boolean, consume: (android.database.Cursor)->Unit) {
                        val dy=radius/111195; val dx=dy/cos(lat*PI/180).coerceAtLeast(.01)
                        val sql="SELECT ${if(payload) "t.payload" else "t.lat,t.lon,t.radius"} FROM $table t JOIN ${table}_rtree r ON r.id=t.id WHERE r.minLon<=? AND r.maxLon>=? AND r.minLat<=? AND r.maxLat>=? LIMIT $limit"
                        db.rawQuery(sql,arrayOf((lon+dx).toString(),(lon-dx).toString(),(lat+dy).toString(),(lat-dy).toString())).use { c -> while(c.moveToNext()) consume(c) }
                    }
                    query("roads",100.0,257,true) { c -> roads.put(JSONObject(c.getString(0))) }
                    query("signs",1700.0,1001,true) { c -> signs.put(JSONObject(c.getString(0))) }
                    query("places",6500.0,500,false) { c ->
                        val dy=(lat-c.getDouble(0))*111195; val dx=(lon-c.getDouble(1))*111195*cos(lat*PI/180)
                        if (hypot(dx,dy)<=c.getDouble(2)) urban=true
                    }
                    truncated=roads.length()>256 || signs.length()>1000
                }
                val raw=JSONObject().put("roads",roads).put("signs",signs).put("urbanHint",urban).put("truncated",truncated).toString()
                handler.post { reply(raw,null) }
            } catch (_: Exception) { handler.post { reply(null,"Không đọc được dữ liệu đường; thử tải lại gói") } }
        }
    }
    fun download() {
        if (downloading) return
        downloading=true; progress=0; message="Đang kiểm tra gói dữ liệu"; emit()
        downloader.execute {
            val compressed=File(context.filesDir,"road-download.gz.part")
            val temp=File(context.filesDir,"road-database.part")
            try {
                val root="https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad/releases/download/road-data/"
                fun connection(url: String): HttpURLConnection {
                    val c=URL(url).openConnection() as HttpURLConnection
                    c.useCaches=false; c.connectTimeout=20000; c.readTimeout=45000; c.instanceFollowRedirects=true
                    c.setRequestProperty("User-Agent","TaxiDriverAADashboard/0.5 offline-pack")
                    require(c.responseCode==200 && c.url.protocol=="https")
                    return c
                }
                val manifestConnection=connection(root+"manifest.json")
                val manifest=try { val bytes=ByteArrayOutputStream(); manifestConnection.inputStream.use { input -> val buffer=ByteArray(8192); while(true) { val count=input.read(buffer); if(count<0) break; require(bytes.size()+count<=128*1024); bytes.write(buffer,0,count) } }; JSONObject(bytes.toString("UTF-8")) } finally { manifestConnection.disconnect() }
                require(manifest.getInt("schema")==1 && manifest.getString("country")=="VN" && manifest.getString("file")=="vietnam-roads.sqlite.gz")
                val bytes=manifest.getLong("bytes"); val dbBytes=manifest.getLong("db_bytes"); val expected=manifest.getString("sha256")
                require(bytes in 1..(200L*1024*1024) && dbBytes in 1..(1536L*1024*1024) && expected.matches(Regex("[a-f0-9]{64}")))
                require(context.filesDir.usableSpace > bytes+dbBytes+32L*1024*1024)
                val c=connection(root+"vietnam-roads.sqlite.gz"); val digest=MessageDigest.getInstance("SHA-256")
                try {
                    var total=0L; var published=0L
                    c.inputStream.use { input -> compressed.outputStream().use { out ->
                        val buffer=ByteArray(65536)
                        while(true) { val count=input.read(buffer); if(count<0) break; total+=count; require(total<=bytes); out.write(buffer,0,count); digest.update(buffer,0,count)
                            if(total-published>=1024*1024) { published=total; val percent=(total*90/bytes).toInt(); handler.post { progress=percent; message="Đang tải gói ${total/1024/1024} / ${bytes/1024/1024} MB"; emit() } }
                        }
                    } }
                    require(total==bytes)
                } finally { c.disconnect() }
                val actual=digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }; require(actual==expected)
                handler.post { progress=92; message="Đang kiểm tra và cài gói ngoại tuyến"; emit() }
                var size=0L
                GZIPInputStream(compressed.inputStream()).use { input -> temp.outputStream().use { out ->
                    val buffer=ByteArray(65536); while(true) { val count=input.read(buffer); if(count<0) break; size+=count; require(size<=dbBytes); out.write(buffer,0,count) }
                } }
                require(size==dbBytes)
                val validated=SQLiteDatabase.openDatabase(temp.path,null,SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS)
                val metadata=validated.use { db ->
                    require(db.version==1)
                    db.rawQuery("PRAGMA quick_check",null).use { check(it.moveToFirst() && it.getString(0)=="ok") }
                    for(table in listOf("roads","signs","places")) {
                        db.rawQuery("SELECT count(*) FROM $table",null).use { check(it.moveToFirst()) }
                        db.rawQuery("SELECT count(*) FROM ${table}_rtree",null).use { check(it.moveToFirst()) }
                    }
                    db.rawQuery("SELECT value FROM metadata WHERE key='info'",null).use { check(it.moveToFirst()); JSONObject(it.getString(0)) }
                }
                require(metadata.getInt("schema")==1 && metadata.getString("country")=="VN")
                worker.submit {
                    database?.close(); database=null
                    check(temp.renameTo(file)) // atomic replacement; old file survives a failed rename
                }.get()
                handler.post { info=metadata; prefs.edit().putString("info",info.toString()).apply(); progress=100; downloading=false; message="Gói dữ liệu đã sẵn sàng ngoại tuyến"; changed() }
            } catch (_: Exception) {
                handler.post { downloading=false; message="Chưa cập nhật được gói. Kiểm tra mạng/dung lượng và thử lại; gói cũ vẫn được giữ."; emit() }
            } finally { compressed.delete(); temp.delete() }
        }
    }
    fun beep() {
        val app=context.applicationContext as DashboardApplication
        if (!settings.optBoolean("beep",false) || !settings.optBoolean("enabled",true) || !app.navigation.running || app.navigation.fix==null) return
        val now=SystemClock.elapsedRealtime(); if(now-lastBeep<30000) return
        val fix=app.navigation.fix!!; if(SystemClock.elapsedRealtimeNanos()-fix.elapsedRealtimeNanos>10_000_000_000L || fix.accuracy>30) return
        lastBeep=now
        val audio=context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val focus=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK).setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).setOnAudioFocusChangeListener {}.build()
        if(audio.requestAudioFocus(focus)!=AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return
        try { val tone=ToneGenerator(AudioManager.STREAM_MUSIC,65); tone.startTone(ToneGenerator.TONE_PROP_BEEP,150); handler.postDelayed({ tone.release(); audio.abandonAudioFocusRequest(focus) },350) }
        catch (_: Exception) { audio.abandonAudioFocusRequest(focus) }
    }
}

class RoadBridge(engine: FlutterEngine, context: Context, private val phone: Boolean) {
    private val store=(context.applicationContext as DashboardApplication).roads
    private val methods=MethodChannel(engine.dartExecutor.binaryMessenger,"taxi/roads")
    private val events=EventChannel(engine.dartExecutor.binaryMessenger,"taxi/roads/events")
    private var sink: EventChannel.EventSink?=null
    private var closed=false
    init {
        methods.setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "snapshot" -> result.success(store.snapshot())
                    "nearby" -> store.nearby(call.argument<Number>("lat")!!.toDouble(),call.argument<Number>("lon")!!.toDouble()) { raw,error -> if(!closed) { if(error==null) result.success(raw) else result.error("ROAD_QUERY",error,null) } }
                    "beep" -> { store.beep(); result.success(null) }
                    else -> { require(phone); when(call.method) {
                        "download" -> { store.download(); result.success(null) }
                        "savePin" -> { store.savePin(call.argument<String>("json")!!); result.success(null) }
                        "deletePin" -> { store.deletePin(call.argument<String>("id")!!); result.success(null) }
                        "importPins" -> { store.importPins(call.argument<String>("json")!!); result.success(null) }
                        "exportPins" -> result.success(store.exportPins())
                        "saveSettings" -> { store.saveSettings(call.argument<String>("json")!!); result.success(null) }
                        else -> result.notImplemented()
                    } }
                }
            } catch (_: Exception) { result.error("ROAD_DATA","Dữ liệu đường/ghim không hợp lệ hoặc chỉ sửa được trên điện thoại",null) }
        }
        events.setStreamHandler(object:EventChannel.StreamHandler {
            override fun onListen(arguments:Any?,events:EventChannel.EventSink) { store.remove(sink); sink=events; store.add(events) }
            override fun onCancel(arguments:Any?) { store.remove(sink); sink=null }
        })
    }
    fun close() { closed=true; store.remove(sink); methods.setMethodCallHandler(null); events.setStreamHandler(null) }
}
