package com.thanhtaxixanh.dashboard

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import org.json.JSONArray

class MediaBridge(private val app: DashboardApplication, private val car: Boolean, private val worker: Boolean) : FlutterPlugin {
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var sink: EventChannel.EventSink? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var textureLease = ""
    private val state get()=app.media
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods=MethodChannel(binding.binaryMessenger,"taxi/media")
        events=EventChannel(binding.binaryMessenger,"taxi/media/events")
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { state.remove(sink); sink=events; state.add(events) }
            override fun onCancel(arguments: Any?) { state.remove(sink); sink=null }
        })
        methods.setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "snapshot" -> result.success(state.snapshot())
                    "refresh" -> { state.external.refresh(); state.motionChanged(); result.success(null) }
                    "notificationSettings" -> {
                        require(!car && !worker)
                        app.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); result.success(null)
                    }
                    "chooseSource" -> { require(!worker); state.chooseSource(call.argument<String>("source") ?: "external"); result.success(null) }
                    "chooseSession" -> { require(!worker); state.external.choose(call.argument<String>("id") ?: ""); result.success(null) }
                    "command" -> { require(!worker); state.command(call.argument<String>("action") ?: "",call.argument<Number>("position")?.toLong() ?: 0); result.success(null) }
                    "saveCollection" -> { require(!car && !worker); state.saveCollection(call.argument<String>("json") ?: ""); result.success(null) }
                    "deleteCollection" -> { require(!car && !worker); state.deleteCollection(call.argument<String>("id") ?: ""); result.success(null) }
                    "playQueue" -> {
                        require(!car && !worker); val raw=call.argument<String>("json") ?: ""; require(raw.toByteArray().size<=512000)
                        state.play(JSONArray(raw),call.argument<Number>("index")?.toInt() ?: 0); result.success(null)
                    }
                    "playSaved" -> { require(!worker); state.playSaved(call.argument<String>("id") ?: "",call.argument<Number>("index")?.toInt() ?: 0); result.success(null) }
                    "resolved" -> {
                        require(worker)
                        state.resolved(call.argument<String>("token") ?: "",call.argument<String>("audio"),call.argument<String>("video"),call.argument<Boolean>("failed") == true)
                        result.success(null)
                    }
                    "video" -> { require(!worker); state.requestVideo(call.argument<Boolean>("enabled") == true); result.success(null) }
                    "createTexture" -> {
                        require(!worker)
                        val lease=call.argument<String>("lease") ?: ""; require(lease.length in 1..100)
                        if (lease!=textureLease) { releaseTexture(); textureLease=lease }
                        if (producer==null) {
                            val created=binding.textureRegistry.createSurfaceProducer(); producer=created; created.setSize(1280,720)
                            created.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
                                override fun onSurfaceAvailable() { attachVideoSurface() }
                                override fun onSurfaceCleanup() { state.removeSurface(this@MediaBridge) }
                            })
                        }
                        attachVideoSurface()
                        result.success(producer!!.id())
                    }
                    "releaseTexture" -> { if (call.argument<String>("lease")==textureLease) releaseTexture(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("MEDIA","Không thực hiện được. Kiểm tra quyền hoặc chọn lại bài",null) }
        }
    }
    private fun attachVideoSurface() { state.attachSurface(this,car,{ producer?.surface },{ width,height -> producer?.setSize(width,height) }) }
    private fun releaseTexture() { state.removeSurface(this); producer?.setCallback(null); producer?.release(); producer=null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        state.remove(sink); sink=null; releaseTexture(); methods.setMethodCallHandler(null); events.setStreamHandler(null)
    }
}
