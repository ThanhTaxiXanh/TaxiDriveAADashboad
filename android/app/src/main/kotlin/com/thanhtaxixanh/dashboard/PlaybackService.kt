package com.thanhtaxixanh.dashboard

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class PlaybackService : MediaSessionService() {
    private var session: MediaSession? = null
    private var player: ExoPlayer? = null
    private val state get()=(application as DashboardApplication).media
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
        val queuePlayer=object : ForwardingPlayer(native) {
            override fun getAvailableCommands(): Player.Commands = super.getAvailableCommands().buildUpon()
                .add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM).add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
                .add(Player.COMMAND_SEEK_TO_NEXT).add(Player.COMMAND_SEEK_TO_PREVIOUS)
                .remove(Player.COMMAND_CHANGE_MEDIA_ITEMS).build()
            override fun isCommandAvailable(command: Int)=availableCommands.contains(command)
            override fun seekToNextMediaItem() { state.skip(1) }
            override fun seekToPreviousMediaItem() { state.skip(-1) }
            override fun seekToNext() { state.skip(1) }
            override fun seekToPrevious() { state.command("previous") }
        }
        session=MediaSession.Builder(this,queuePlayer).setSessionActivity(open).build()
        state.attach(this,native)
    }
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session
    override fun onDestroy() {
        state.detach(); session?.release(); session=null; player?.release(); player=null
        super.onDestroy()
    }
}
