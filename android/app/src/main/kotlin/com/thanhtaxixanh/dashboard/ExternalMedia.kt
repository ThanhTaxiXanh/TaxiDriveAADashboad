package com.thanhtaxixanh.dashboard

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.util.Base64
import androidx.core.app.NotificationManagerCompat
import java.io.ByteArrayOutputStream
import org.json.JSONArray
import org.json.JSONObject

// Never read notifications: the enabled listener only grants MediaSession access.
class MediaNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() { (application as DashboardApplication).media.external.refresh() }
    override fun onListenerDisconnected() { (application as DashboardApplication).media.external.disconnect() }
}

class ExternalMedia(private val context: Context, private val changed: () -> Unit) {
    private val manager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
    private val component = ComponentName(context, MediaNotificationListener::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var watching = false
    private var sessions = emptyList<MediaController>()
    private var chosen: String? = null
    private var selected: MediaController? = null
    private var artwork: String? = null
    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) { updateArtwork(); changed() }
        override fun onPlaybackStateChanged(state: PlaybackState?) { update(sessions) }
        override fun onSessionDestroyed() { refresh() }
    }
    private val listener = MediaSessionManager.OnActiveSessionsChangedListener { update(it ?: emptyList()) }
    val allowed get() = NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)
    fun refresh() {
        if (!allowed) { disconnect(); return }
        try {
            if (!watching) { manager.addOnActiveSessionsChangedListener(listener, component, handler); watching = true }
            update(manager.getActiveSessions(component))
        } catch (_: SecurityException) { disconnect() }
    }
    fun disconnect() {
        if (watching) { try { manager.removeOnActiveSessionsChangedListener(listener) } catch (_: Exception) {} }
        watching = false; update(emptyList())
    }
    private fun id(controller: MediaController) = controller.sessionToken.hashCode().toString()
    private fun update(all: List<MediaController>) {
        sessions.forEach { it.unregisterCallback(callback) }
        sessions = all.filter { it.packageName != context.packageName }.take(20)
        sessions.forEach { it.registerCallback(callback, handler) }
        val next = sessions.firstOrNull { id(it) == chosen }
            ?: sessions.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: sessions.firstOrNull()
        if (next?.sessionToken != selected?.sessionToken) {
            selected = next; updateArtwork()
        }
        changed()
    }
    private fun updateArtwork() {
        artwork = null
        try {
            val metadata = selected?.metadata ?: return
            val image = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON) ?: return
            val factor = 160.0 / maxOf(image.width, image.height).coerceAtLeast(1)
            val thumb = Bitmap.createScaledBitmap(image, maxOf(1, (image.width * minOf(1.0, factor)).toInt()), maxOf(1, (image.height * minOf(1.0, factor)).toInt()), true)
            val output = ByteArrayOutputStream(); thumb.compress(Bitmap.CompressFormat.JPEG, 82, output)
            if (output.size() <= 100000) artwork = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
            if (thumb !== image) thumb.recycle()
        } catch (_: Exception) { artwork = null }
    }
    fun choose(token: String) { require(sessions.any { id(it) == token }); chosen = token; update(sessions) }
    private fun appName(controller: MediaController): String = try {
        context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(controller.packageName, 0)).toString().take(100)
    } catch (_: Exception) { controller.packageName }
    fun snapshot(): JSONObject {
        val controller = selected; val state = controller?.playbackState; val metadata = controller?.metadata
        val duration = (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0).coerceAtLeast(0)
        val playing = state?.state == PlaybackState.STATE_PLAYING
        return JSONObject().put("permission", allowed).put("available", controller != null)
            .put("sessions", JSONArray().also { result -> sessions.forEach { result.put(JSONObject().put("id",id(it)).put("name",appName(it))) } })
            .put("selected", controller?.let { id(it) } ?: "")
            .put("app",controller?.let { appName(it) } ?: "Ứng dụng nhạc")
            .put("title",(metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE) ?: "Chưa có bài đang phát").take(200))
            .put("artist",(metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "").take(200))
            .put("art",artwork ?: JSONObject.NULL).put("playing",playing).put("duration",duration)
            .put("position",MediaPolicy.position(state?.position ?: 0,state?.lastPositionUpdateTime ?: SystemClock.elapsedRealtime(),SystemClock.elapsedRealtime(),state?.playbackSpeed ?: 0f,playing,duration))
            .put("actions",state?.actions ?: 0)
    }
    fun command(action: String, position: Long = 0) {
        if (!allowed) { disconnect(); return }
        val controller = selected ?: return
        val controls = controller.transportControls; val flags = controller.playbackState?.actions ?: 0
        fun supports(flag: Long) = flags and flag != 0L
        when (action) {
            "play" -> if (supports(PlaybackState.ACTION_PLAY) || supports(PlaybackState.ACTION_PLAY_PAUSE)) controls.play()
            "pause" -> if (supports(PlaybackState.ACTION_PAUSE) || supports(PlaybackState.ACTION_PLAY_PAUSE)) controls.pause()
            "previous" -> if (supports(PlaybackState.ACTION_SKIP_TO_PREVIOUS)) controls.skipToPrevious()
            "next" -> if (supports(PlaybackState.ACTION_SKIP_TO_NEXT)) controls.skipToNext()
            "seek" -> if (supports(PlaybackState.ACTION_SEEK_TO)) controls.seekTo(position.coerceAtLeast(0))
        }
    }
}
