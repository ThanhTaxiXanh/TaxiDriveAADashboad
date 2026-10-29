package com.thanhtaxixanh.dashboard

import androidx.media3.common.C
import androidx.media3.common.ForwardingSimpleBasePlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

// ExoPlayer loads only the currently resolved stream. Publish the actual saved
// queue to MediaSession instead of telling Android Auto it is a one-item player.
// ForwardingSimpleBasePlayer also keeps command/listener events consistent.
@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class QueueSessionPlayer(
    delegate: Player,
    private val items: () -> List<MediaItem>,
    private val index: () -> Int,
    private val pending: () -> Boolean,
    private val wantedPlaying: () -> Boolean,
    private val command: (String, Long) -> Unit,
    private val select: (Int) -> Unit,
) : ForwardingSimpleBasePlayer(delegate) {
    fun refresh() = invalidateState()

    override fun getState(): State {
        val original = super.getState()
        val queue = items()
        val current = if (queue.isEmpty()) C.INDEX_UNSET else index().coerceIn(0, queue.lastIndex)
        val commands = original.availableCommands.buildUpon()
            .add(Player.COMMAND_GET_TIMELINE)
            .add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
            .add(Player.COMMAND_GET_METADATA)
            .remove(Player.COMMAND_CHANGE_MEDIA_ITEMS)
            .remove(Player.COMMAND_SET_MEDIA_ITEM)
            .remove(Player.COMMAND_SET_SHUFFLE_MODE)
            .remove(Player.COMMAND_SET_REPEAT_MODE)
            .remove(Player.COMMAND_SEEK_TO_NEXT)
            .remove(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
            .remove(Player.COMMAND_SEEK_TO_PREVIOUS)
            .remove(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
        if (queue.isNotEmpty()) {
            commands.add(Player.COMMAND_PLAY_PAUSE).add(Player.COMMAND_PREPARE).add(Player.COMMAND_STOP)
                .add(Player.COMMAND_SEEK_TO_MEDIA_ITEM)
            if (current < queue.lastIndex) commands.add(Player.COMMAND_SEEK_TO_NEXT).add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
            if (current > 0) commands.add(Player.COMMAND_SEEK_TO_PREVIOUS).add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
        }
        val playlist = queue.mapIndexed { position, item ->
            MediaItemData.Builder("$position:${item.mediaId}")
                .setMediaItem(item)
                .setIsSeekable(position == current && player.isCurrentMediaItemSeekable)
                .setDurationUs(if (position == current && player.duration > 0) player.duration * 1000 else C.TIME_UNSET)
                .build()
        }
        val builder = original.buildUpon()
            .setPlaylist(playlist)
            .setCurrentMediaItemIndex(current)
            .setAvailableCommands(commands.build())
            // Previous means the previous item, including after listening >3 s.
            .setMaxSeekToPreviousPositionMs(Long.MAX_VALUE)
            .setPlayWhenReady(wantedPlaying(), Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
        if (pending() && queue.isNotEmpty()) builder.setPlaybackState(Player.STATE_BUFFERING).setIsLoading(true).setPlayerError(null)
        if (queue.isEmpty()) builder.setPlaybackState(Player.STATE_IDLE).setIsLoading(false).setPlayWhenReady(false, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
        return builder.build()
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        command(if (playWhenReady) "play" else "pause", 0)
        return Futures.immediateVoidFuture()
    }

    override fun handlePrepare(): ListenableFuture<*> {
        // The shared queue resolves only on an explicit Play request.
        return Futures.immediateVoidFuture()
    }

    override fun handleStop(): ListenableFuture<*> {
        command("stop", 0)
        return Futures.immediateVoidFuture()
    }

    override fun handleSeek(mediaItemIndex: Int, positionMs: Long, seekCommand: Int): ListenableFuture<*> {
        when (seekCommand) {
            Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM -> command("next", 0)
            Player.COMMAND_SEEK_TO_PREVIOUS, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> command("previous", 0)
            Player.COMMAND_SEEK_TO_MEDIA_ITEM -> {
                if (mediaItemIndex != C.INDEX_UNSET && mediaItemIndex != index()) select(mediaItemIndex)
                else if (positionMs != C.TIME_UNSET) command("seek", positionMs.coerceAtLeast(0))
            }
            Player.COMMAND_SEEK_TO_DEFAULT_POSITION -> command("seek", 0)
            else -> if (positionMs != C.TIME_UNSET) command("seek", positionMs.coerceAtLeast(0))
        }
        return Futures.immediateVoidFuture()
    }
}
