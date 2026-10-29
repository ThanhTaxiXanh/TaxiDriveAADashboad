package com.thanhtaxixanh.dashboard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Surface
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

// One private queue/player and one resolver engine for phone + projected UI.
// Signed stream URLs live only in the player; no URLs/titles enter Diagnostics.
@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class MediaState(private val app: DashboardApplication) {
    private val prefs = app.getSharedPreferences("media", Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    val external = ExternalMedia(app) { emit() }
    private val sinks = mutableSetOf<EventChannel.EventSink>()
    var service: PlaybackService? = null
    var player: ExoPlayer? = null
        private set
    private var resolver: FlutterEngine? = null
    var source = prefs.getString("source", "external") ?: "external"
        private set
    private var library = JSONArray(prefs.getString("library", "[]"))
    private var recent = JSONArray(prefs.getString("recent", "[]"))
    private var queue = JSONArray()
    private var index = 0
    private var revision = 0L
    private var pending = false
    private var requestToken = ""
    private var wantedPlaying = false
    private var resumePosition = 0L
    private var retried = false
    private var videoRequested = false
    private var hasVideo = false
    private var lastAudio: String? = null
    private var visibleVideo = false
    private var lastCarConnection = false
    private var playedMs = 0L
    private var lastPlayingAt = SystemClock.elapsedRealtime()
    private var wasPlaying = false
    private var surfaceOwner: Any? = null
    private var surface: (() -> Surface?)? = null
    private var surfaceCar = false
    private var resizeSurface: ((Int,Int)->Unit)? = null
    private var width = 1280
    private var height = 720
    var message = "Chọn ứng dụng nhạc hoặc danh sách YouTube"
        private set
    private var ticking = false
    private val tick = object : Runnable {
        override fun run() {
            samplePlayTime(); updateVideo(); emit()
            if (ticking) handler.postDelayed(this, 1000)
        }
    }
    private fun ensureTick() { if (!ticking) { ticking = true; handler.post(tick) } }
    fun add(sink: EventChannel.EventSink) { sinks.add(sink); ensureTick(); external.refresh(); sink.success(snapshot()) }
    fun remove(sink: EventChannel.EventSink?) { sinks.remove(sink); stopTickIfIdle() }
    private fun stopTickIfIdle() { if (sinks.isEmpty() && service == null) { ticking = false; handler.removeCallbacks(tick) } }
    fun emit(full: Boolean = false) { revision++; service?.refreshSession(); if (sinks.isNotEmpty()) { val raw = snapshot(full); sinks.toList().forEach { it.success(raw) } } }
    fun sessionItems(): List<MediaItem> = (0 until queue.length()).map { offset ->
        val item=queue.getJSONObject(offset)
        MediaItem.Builder().setMediaId(item.getString("id")).setMediaMetadata(
            MediaMetadata.Builder().setTitle(item.getString("title")).setArtist(item.getString("author")).build()
        ).build()
    }
    fun sessionIndex(): Int = index
    fun sessionPending(): Boolean = pending
    fun sessionPlayWhenReady(): Boolean = wantedPlaying
    fun selectQueueItem(next: Int) {
        if (source!="youtube" || next !in 0 until queue.length()) return
        index=next; wantedPlaying=true; request()
    }
    private fun current(): JSONObject? = queue.optJSONObject(index)
    fun videoSafe(): Boolean {
        val nav = app.navigation; val fix = nav.fix ?: return false
        return MediaPolicy.videoAllowed(nav.running, SystemClock.elapsedRealtime() - fix.elapsedRealtimeNanos / 1000000,
            fix.accuracy.toDouble(), if (fix.hasSpeed()) fix.speed * 3.6 else -1.0)
    }
    private fun samplePlayTime() {
        val now=SystemClock.elapsedRealtime()
        if (wasPlaying) playedMs+=(now-lastPlayingAt).coerceAtLeast(0)
        lastPlayingAt=now; wasPlaying=player?.isPlaying==true
    }
    fun snapshot(full: Boolean = true): String = JSONObject().put("source",source).put("external",external.snapshot())
        .also { if (full) it.put("library",library).put("recent",recent) }.put("queueCount",queue.length()).put("index",index)
        .put("revision",revision).put("request",if (pending) JSONObject().put("token",requestToken).put("entry",current()) else JSONObject.NULL)
        .put("title",current()?.optString("title") ?: "Chưa chọn bài")
        .put("artist",current()?.optString("author") ?: "YouTube")
        .put("playing",player?.isPlaying == true).put("wantedPlaying",wantedPlaying)
        .put("loading",pending || player?.playbackState == Player.STATE_BUFFERING)
        .put("position",(player?.currentPosition ?: resumePosition).coerceAtLeast(0))
        .put("duration",(player?.duration ?: 0).coerceAtLeast(0)).put("message",message)
        .put("videoRequested",videoRequested).put("videoSafe",videoSafe()).put("videoVisible",visibleVideo)
        .put("hasVideo",hasVideo).put("videoAspect",width.toDouble()/height.coerceAtLeast(1))
        .put("carConnected",app.navigation.carConnected).put("playedMs",playedMs).toString()

    private fun entry(input: JSONObject): JSONObject {
        val id = input.getString("id"); require(id.matches(Regex("[A-Za-z0-9_-]{11}")))
        val title = input.optString("title", "YouTube").trim().take(200).ifEmpty { "YouTube" }
        return JSONObject().put("id",id).put("title",title).put("author",input.optString("author", "").take(150))
            .put("duration",input.optLong("duration",0).coerceIn(0,864000000))
    }
    private fun entries(raw: JSONArray): JSONArray {
        require(raw.length() in 1..200)
        return JSONArray().also { out -> for (i in 0 until raw.length()) out.put(entry(raw.getJSONObject(i))) }
    }
    fun saveCollection(raw: String) {
        require(raw.toByteArray().size <= 512000)
        val input = JSONObject(raw); val id = input.getString("id")
        require(id.matches(Regex("[A-Za-z0-9_-]{1,120}")))
        val value = JSONObject().put("id",id).put("title",input.getString("title").take(200))
            .put("favorite",input.optBoolean("favorite",true)).put("entries",entries(input.getJSONArray("entries")))
        if (library.length()>=60 && (0 until library.length()).none { library.getJSONObject(it).getString("id")==id }) throw IllegalStateException("MEDIA_LIMIT")
        val next = JSONArray().put(value)
        for (i in 0 until library.length()) if (library.getJSONObject(i).getString("id") != id) next.put(library.getJSONObject(i))
        require(next.toString().toByteArray().size <= 2*1024*1024)
        library = next; persist(); emit(true)
    }
    fun deleteCollection(id: String) {
        val next = JSONArray(); for (i in 0 until library.length()) if (library.getJSONObject(i).getString("id") != id) next.put(library.getJSONObject(i))
        library = next; persist(); emit(true)
    }
    private fun persist() { prefs.edit().putString("library",library.toString()).putString("recent",recent.toString()).putString("source",source).apply() }
    fun chooseSource(next: String) {
        require(next == "external" || next == "youtube")
        source=next
        if (next == "external") {
            resumePosition=(player?.currentPosition ?: resumePosition).coerceAtLeast(0)
            videoRequested=false; wantedPlaying=false; pending=false; revision++
            player?.pause(); service?.handoffToExternal(); message="Điều khiển ứng dụng nhạc"
        }
        persist(); updateVideo(); external.refresh(); emit()
    }
    fun playSaved(id: String, offset: Int = 0) {
        val collection=(0 until library.length()).map { library.getJSONObject(it) }.firstOrNull { it.getString("id")==id }
        if (collection != null) play(collection.getJSONArray("entries"),offset)
        else { val saved=(0 until recent.length()).map { recent.getJSONObject(it) }.firstOrNull { it.getString("id")==id } ?: error("Missing saved item"); play(JSONArray().put(saved),0) }
    }
    fun play(input: JSONArray, offset: Int) {
        val next=entries(input); require(offset in 0 until next.length())
        queue=next; index=offset; source="youtube"; wantedPlaying=true; videoRequested=false; playedMs=0; wasPlaying=false; lastPlayingAt=SystemClock.elapsedRealtime(); persist()
        if (startService()) request()
    }
    private fun startService(): Boolean {
        if (service != null) return true
        return try { ContextCompat.startForegroundService(app,Intent(app,PlaybackService::class.java)); true }
        catch (_: Exception) { wantedPlaying=false; message="Android chưa cho phát nền; mở ứng dụng điện thoại và thử lại"; emit(); false }
    }
    fun attach(service: PlaybackService, next: ExoPlayer) {
        this.service=service; player=next; ensureTick()
        next.addListener(object : Player.Listener {
            override fun onEvents(player: Player, events: Player.Events) { if (this@MediaState.player!==next) return; samplePlayTime(); updateVideo(); emit() }
            override fun onPlaybackStateChanged(state: Int) {
                if (player!==next) return
                if (state==Player.STATE_ENDED && wantedPlaying && !pending) {
                    if (index+1<queue.length()) skip(1) else { wantedPlaying=false; message="Đã phát hết danh sách"; emit() }
                }
            }
            override fun onPlayerError(error: PlaybackException) {
                if (player!==next) return
                if (hasVideo && lastAudio!=null && wantedPlaying) {
                    pending=true; resumePosition=next.currentPosition.coerceAtLeast(0)
                    resolved(requestToken,lastAudio,null,false); message="Luồng video chưa phát được; tiếp tục âm thanh"; emit()
                } else if (!retried && current()!=null && wantedPlaying) {
                    retried=true; resumePosition=next.currentPosition.coerceAtLeast(0); request(keepRetry=true,keepPosition=true)
                } else { wantedPlaying=false; pending=false; message="Không phát được luồng này. Kiểm tra mạng hoặc chọn bài khác"; emit() }
            }
            override fun onVideoSizeChanged(size: VideoSize) {
                if (player!==next) return
                if (size.width>0 && size.height>0 && (width!=size.width || height!=size.height)) { width=size.width; height=size.height; resizeSurface?.invoke(width,height); updateVideo(forceSurface=true); emit() }
            }
        })
        if (resolver==null) resolver=app.engine("mediaMain")
        emit()
    }
    fun detach(owner: PlaybackService) {
        if (service!==owner) return
        samplePlayTime(); wasPlaying=false; service=null; player=null; pending=false; wantedPlaying=false; videoRequested=false; hasVideo=false; lastAudio=null; revision++; visibleVideo=false
        val old=resolver; resolver=null; handler.post { old?.destroy() }; stopTickIfIdle(); emit()
    }
    private fun request(keepRetry: Boolean = false, keepPosition: Boolean = false) {
        if (current()==null) return
        if (!keepRetry) retried=false
        if (!keepPosition) resumePosition=0
        revision++; requestToken=UUID.randomUUID().toString(); pending=true; hasVideo=false; visibleVideo=false
        player?.stop(); player?.clearMediaItems(); message="Đang lấy luồng YouTube"; emit()
        val token=requestToken
        handler.postDelayed({ if (pending && token==requestToken) { pending=false; wantedPlaying=false; message="YouTube phản hồi quá lâu. Chọn Phát để thử lại"; emit() } },45000)
    }
    fun resolved(token: String, audioUrl: String?, videoUrl: String?, failed: Boolean, muxed: Boolean = false) {
        if (!pending || token!=requestToken || current()==null) return
        if (failed) { pending=false; wantedPlaying=false; message="Chưa lấy được luồng YouTube. Thử lại trên mạng điện thoại hoặc chọn bài khác"; emit(); return }
        fun checked(raw: String?): String? {
            if (raw.isNullOrBlank()) return null
            val uri=android.net.Uri.parse(raw); val host=uri.host ?: error("Missing stream host")
            require(raw.length<=16384 && uri.scheme=="https" && host.endsWith(".googlevideo.com") && uri.userInfo==null)
            return raw
        }
        val audio=checked(audioUrl) ?: error("Missing audio"); val video=checked(videoUrl)
        lastAudio=audio
        val p=player ?: return
        val item=current()!!
        val metadata=MediaMetadata.Builder().setTitle(item.getString("title")).setArtist(item.getString("author")).build()
        val factory=ProgressiveMediaSource.Factory(DefaultDataSource.Factory(app,DefaultHttpDataSource.Factory()
            .setUserAgent("Mozilla/5.0").setConnectTimeoutMs(15000).setReadTimeoutMs(20000)))
        fun media(url: String)=factory.createMediaSource(MediaItem.Builder().setMediaId(item.getString("id")).setUri(url).setMediaMetadata(metadata).build())
        val audioSource=media(audio)
        hasVideo=video!=null || muxed; pending=false
        p.setMediaSource(if (video!=null) MergingMediaSource(media(video),audioSource) else audioSource,resumePosition)
        updateVideo(); p.prepare(); p.playWhenReady=wantedPlaying
        message=if (muxed) "Âm thanh từ video 360p · chế độ tương thích dùng thêm dữ liệu" else if (video==null) "Đang phát âm thanh · bài này chưa có luồng video phù hợp" else "YouTube · phát âm thanh mặc định"
        val next=JSONArray().put(item)
        for (i in 0 until recent.length()) if (recent.getJSONObject(i).getString("id")!=item.getString("id") && next.length()<40) next.put(recent.getJSONObject(i))
        recent=next; persist(); emit(true)
    }
    fun skip(delta: Int) {
        val next=index+delta
        if (next !in 0 until queue.length()) return
        index=next; wantedPlaying=true; request()
    }
    fun command(action: String, position: Long = 0) {
        if (source=="external") { if (action=="play") player?.pause(); external.command(action,position); return }
        when(action) {
            "play" -> { wantedPlaying=true; if (player==null && !startService()) return; if (player?.playbackState==Player.STATE_IDLE || player==null) request(keepPosition=true) else { if (player?.playbackState==Player.STATE_ENDED) player?.seekTo(0); player?.play() } }
            "pause" -> { wantedPlaying=false; player?.pause() }
            "next" -> skip(1)
            "previous" -> skip(-1)
            "seek" -> if (!pending) player?.seekTo(position.coerceIn(0,(player?.duration ?: 0).coerceAtLeast(0)))
            "stop" -> { wantedPlaying=false; pending=false; resumePosition=0; videoRequested=false; hasVideo=false; lastAudio=null; revision++; player?.stop(); player?.clearMediaItems(); message="Đã dừng YouTube"; service?.stopSelf() }
        }
        updateVideo(); emit()
    }
    fun requestVideo(value: Boolean) { videoRequested=value && videoSafe(); updateVideo(); emit() }
    fun motionChanged() { updateVideo(); emit() }
    fun attachSurface(owner: Any, car: Boolean, value: (() -> Surface?), resize: (Int,Int)->Unit) {
        if (app.navigation.carConnected && !car) return
        surfaceOwner=owner; surfaceCar=car; surface=value; resizeSurface=resize; resize(width,height); updateVideo(forceSurface=true)
    }
    fun removeSurface(owner: Any) { if (surfaceOwner===owner) { surface=null; resizeSurface=null; surfaceOwner=null; updateVideo(forceSurface=true); emit() } }
    private fun updateVideo(forceSurface: Boolean = false) {
        val connected=app.navigation.carConnected
        if (lastCarConnection != connected) { videoRequested=false; lastCarConnection=connected }
        val safe=videoSafe()
        if (!safe || source!="youtube") videoRequested=false // No automatic reappearance after moving.
        val show=source=="youtube" && hasVideo && videoRequested && safe && surface!=null && (!app.navigation.carConnected || surfaceCar)
        if (show!=visibleVideo || forceSurface) {
            visibleVideo=show
            player?.trackSelectionParameters=player!!.trackSelectionParameters.buildUpon().setTrackTypeDisabled(C.TRACK_TYPE_VIDEO,!show).build()
            if (show) player?.setVideoSurface(surface?.invoke()) else player?.clearVideoSurface()
        }
    }
}
