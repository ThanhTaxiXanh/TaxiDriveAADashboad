package com.thanhtaxixanh.dashboard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class PlaybackService : MediaSessionService() {
    private var session: MediaSession? = null
    private var player: ExoPlayer? = null
    private var queuePlayer: QueueSessionPlayer? = null
    private var closing = false
    private val state get()=(application as DashboardApplication).media
    private val buttons = MediaButtonRouter({ state.sessionPlayWhenReady() }, { state.command(it) })
    override fun onCreate() {
        super.onCreate()
        val notifications=getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        notifications.createNotificationChannel(NotificationChannel("media","Nhạc và YouTube",NotificationManager.IMPORTANCE_LOW))
        val open=PendingIntent.getActivity(this,4,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        startForeground(406,NotificationCompat.Builder(this,"media").setSmallIcon(R.drawable.ic_taxi)
            .setContentTitle("Taxi Xanh · Đang chuẩn bị nhạc").setContentIntent(open).setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build())
        setMediaNotificationProvider(DefaultMediaNotificationProvider.Builder(this).setNotificationId(406).setChannelId("media").build())
        val native=ExoPlayer.Builder(this).build().also {
            it.setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),true)
            it.setHandleAudioBecomingNoisy(true)
            it.setWakeMode(C.WAKE_MODE_NETWORK)
            it.trackSelectionParameters=it.trackSelectionParameters.buildUpon().setTrackTypeDisabled(C.TRACK_TYPE_VIDEO,true).build()
        }
        player=native
        val adapter=QueueSessionPlayer(native,state::sessionItems,state::sessionIndex,state::sessionPending,state::sessionPlayWhenReady,state::command,state::selectQueueItem)
        queuePlayer=adapter
        session=MediaSession.Builder(this,adapter).setSessionActivity(open).setCallback(object : MediaSession.Callback {
            override fun onMediaButtonEvent(session: MediaSession, controllerInfo: MediaSession.ControllerInfo, intent: Intent): Boolean =
                !closing && state.source=="youtube" && buttons.handle(intent)
        }).build()
        state.attach(this,native)
    }
    fun refreshSession() { if (!closing) queuePlayer?.refresh() }
    fun handleMediaKeyEvent(event: KeyEvent): Boolean = !closing && state.source=="youtube" && buttons.handle(event)
    fun handoffToExternal() {
        if (closing) return
        closing=true
        // Release immediately; a paused own session must not remain the target
        // for hardware media keys intended for Spotify/Zing/YouTube Music.
        player?.pause()
        session?.release(); session=null
        state.detach(this)
        stopSelf()
    }
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session
    override fun onDestroy() {
        closing=true
        state.detach(this); session?.release(); session=null; queuePlayer?.release(); queuePlayer=null; player=null
        super.onDestroy()
    }
}
