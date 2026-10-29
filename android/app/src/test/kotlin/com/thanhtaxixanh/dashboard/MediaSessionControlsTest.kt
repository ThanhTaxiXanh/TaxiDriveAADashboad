package com.thanhtaxixanh.dashboard

import android.app.Application
import android.content.Intent
import android.os.Looper
import android.view.KeyEvent
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowLooper

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [33], manifest = Config.NONE)
@LooperMode(LooperMode.Mode.PAUSED)
@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class MediaSessionControlsTest {
    private class NativeFixture : SimpleBasePlayer(Looper.getMainLooper()) {
        var position = 45000L
        var buffering = false
        var playWanted = true
        var hasResolvedItem = true
        var resolvedId = "native-current"
        var commands = Player.Commands.Builder().addAllCommands().build()
        val nativeSeekCalls = mutableListOf<Long>()
        override fun getState(): State = State.Builder()
            .setAvailableCommands(commands)
            .setPlaylist(if (hasResolvedItem) listOf(MediaItemData.Builder("one-resolved-url")
                .setMediaItem(MediaItem.Builder().setMediaId(resolvedId).build())
                .setDurationUs(180000000).setIsSeekable(true).build()) else emptyList())
            .setCurrentMediaItemIndex(if (hasResolvedItem) 0 else C.INDEX_UNSET)
            .setContentPositionMs(if (hasResolvedItem) position else 0)
            .setContentBufferedPositionMs { if (hasResolvedItem) position else 0L }
            .setPlaybackState(if (!hasResolvedItem) Player.STATE_IDLE else if (buffering) Player.STATE_BUFFERING else Player.STATE_READY)
            .setIsLoading(buffering && hasResolvedItem)
            .setPlayWhenReady(playWanted, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
            .build()
        override fun handleSeek(mediaItemIndex: Int, positionMs: Long, seekCommand: Int): ListenableFuture<*> {
            nativeSeekCalls.add(positionMs); position=positionMs
            return Futures.immediateVoidFuture()
        }
        override fun handleRelease(): ListenableFuture<*> = Futures.immediateVoidFuture()
        fun announceChanged() = invalidateState()
    }
    private class QueueFixture {
        val native=NativeFixture()
        val items=listOf("first","second","third").map { id ->
            MediaItem.Builder().setMediaId(id).setMediaMetadata(MediaMetadata.Builder().setTitle(id).build()).build()
        }
        var index=1
        var pending=false
        var wanted=true
        val calls=mutableListOf<String>()
        val player=QueueSessionPlayer(native,{items},{index},{pending},{wanted},{ action,position ->
            calls.add(action)
            when(action) {
                "next" -> if (index+1<items.size) index++
                "previous" -> if (index>0) index--
                "play" -> wanted=true
                "pause" -> wanted=false
                "seek" -> native.position=position
            }
        },{ selected -> index=selected })
    }

    @Test fun controllerSeesRealQueueAndCanSkipDespiteOneResolvedNativeItem() {
        val fixture=QueueFixture(); val player=fixture.player
        assertEquals(1,fixture.native.mediaItemCount)
        assertEquals(3,player.mediaItemCount)
        assertEquals("second",player.currentMediaItem?.mediaId)
        assertTrue(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM))
        assertTrue(player.isCommandAvailable(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM))
        assertFalse(player.isCommandAvailable(Player.COMMAND_CHANGE_MEDIA_ITEMS))
        assertFalse(player.isCommandAvailable(Player.COMMAND_SET_MEDIA_ITEM))
        player.seekToNext()
        assertEquals(listOf("next"),fixture.calls)
        assertEquals(2,fixture.index)
        assertEquals("third",player.currentMediaItem?.mediaId)
        assertFalse(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT))
        player.seekToNext()
        assertEquals(1,fixture.calls.size)
        player.release()
    }

    @Test fun previousAfterFortyFiveSecondsChangesTrackRatherThanRewinding() {
        val fixture=QueueFixture(); val player=fixture.player
        assertEquals(45000L,player.currentPosition)
        player.seekToPrevious()
        assertEquals(0,fixture.index)
        assertEquals(listOf("previous"),fixture.calls)
        assertTrue(fixture.native.nativeSeekCalls.isEmpty())
        assertEquals("first",player.currentMediaItem?.mediaId)
        assertFalse(player.isCommandAvailable(Player.COMMAND_SEEK_TO_PREVIOUS))
        player.release()
    }

    @Test fun delegateCommandChangesCannotHideVirtualQueueActionsOrLeakDelegateEvents() {
        val fixture=QueueFixture(); val player=fixture.player
        val seenPlayers=mutableListOf<Player>()
        val seenCommands=mutableListOf<Player.Commands>()
        player.addListener(object : Player.Listener {
            override fun onEvents(eventPlayer: Player, events: Player.Events) { seenPlayers.add(eventPlayer) }
            override fun onAvailableCommandsChanged(commands: Player.Commands) { seenCommands.add(commands) }
        })
        // SimpleBasePlayer initializes its state on the first getter, not when
        // listeners are added. Observe the initial state before changing it.
        assertEquals(Player.STATE_READY,player.playbackState)
        assertEquals("second",player.currentMediaItem?.mediaId)
        fixture.native.commands=fixture.native.commands.buildUpon()
            .remove(Player.COMMAND_SEEK_TO_NEXT).remove(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
            .remove(Player.COMMAND_SEEK_TO_PREVIOUS).remove(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM).build()
        fixture.native.buffering=true
        fixture.native.announceChanged(); ShadowLooper.idleMainLooper()
        assertEquals(Player.STATE_BUFFERING,player.playbackState)
        assertTrue(player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT))
        assertTrue(player.isCommandAvailable(Player.COMMAND_SEEK_TO_PREVIOUS))
        assertTrue(seenCommands.all { it.contains(Player.COMMAND_SEEK_TO_NEXT) && it.contains(Player.COMMAND_SEEK_TO_PREVIOUS) })
        assertTrue("READY to BUFFERING must emit an adapter event",seenPlayers.isNotEmpty())
        assertTrue(seenPlayers.all { it===player })
        // A real virtual-queue boundary must publish the transformed command
        // change, even though the underlying one-item player did not change.
        fixture.index=2; player.refresh(); ShadowLooper.idleMainLooper()
        assertTrue("Queue boundary must emit available commands",seenCommands.isNotEmpty())
        assertFalse(seenCommands.last().contains(Player.COMMAND_SEEK_TO_NEXT))
        assertTrue(seenCommands.last().contains(Player.COMMAND_SEEK_TO_PREVIOUS))
        assertTrue(seenPlayers.all { it===player })
        player.release()
    }

    @Test fun pendingStreamRemainsPausableAndCanAdvanceToAnotherQueueItem() {
        val fixture=QueueFixture(); fixture.pending=true
        val player=fixture.player
        assertEquals(Player.STATE_BUFFERING,player.playbackState)
        assertTrue(player.playWhenReady)
        player.pause()
        assertFalse(fixture.wanted)
        player.seekToNextMediaItem()
        assertEquals(2,fixture.index)
        assertEquals(listOf("pause","next"),fixture.calls)
        player.release()
    }

    @Test fun queueSurvivesUnresolvedEmptyNativeTimelineAndReplacementStream() {
        val fixture=QueueFixture()
        fixture.native.hasResolvedItem=false; fixture.pending=true
        fixture.native.announceChanged(); fixture.player.refresh()
        assertEquals(0,fixture.native.mediaItemCount)
        assertEquals(3,fixture.player.mediaItemCount)
        assertEquals(Player.STATE_BUFFERING,fixture.player.playbackState)
        assertTrue(fixture.player.isCommandAvailable(Player.COMMAND_PLAY_PAUSE))
        fixture.player.seekToNextMediaItem()
        assertEquals(2,fixture.index)
        fixture.pending=false; fixture.native.hasResolvedItem=true
        fixture.native.resolvedId="new-resolved-stream"; fixture.native.position=0
        fixture.native.announceChanged(); fixture.player.refresh(); ShadowLooper.idleMainLooper()
        assertEquals("third",fixture.player.currentMediaItem?.mediaId)
        assertEquals(2,fixture.player.currentMediaItemIndex)
        assertTrue(fixture.player.isCommandAvailable(Player.COMMAND_SEEK_TO_PREVIOUS))
        assertFalse(fixture.player.isCommandAvailable(Player.COMMAND_SEEK_TO_NEXT))
        fixture.player.release()
    }

    private fun key(code: Int, down: Long, action: Int = KeyEvent.ACTION_DOWN, repeat: Int = 0) =
        KeyEvent(down,down+repeat,action,code,repeat)

    @Test fun onePhysicalPressSkipsOnceAcrossDownRepeatUpAndDuplicateDelivery() {
        val fixture=QueueFixture(); val router=MediaButtonRouter({fixture.wanted},{fixture.player.let { player ->
            when(it) { "next" -> player.seekToNextMediaItem(); "previous" -> player.seekToPreviousMediaItem() }
        }})
        assertTrue(router.handle(key(KeyEvent.KEYCODE_MEDIA_NEXT,100)))
        assertTrue(router.handle(key(KeyEvent.KEYCODE_MEDIA_NEXT,100,repeat=1)))
        assertTrue(router.handle(key(KeyEvent.KEYCODE_MEDIA_NEXT,100,KeyEvent.ACTION_UP)))
        assertTrue(router.handle(key(KeyEvent.KEYCODE_MEDIA_NEXT,100)))
        assertEquals(listOf("next"),fixture.calls)
        assertEquals(2,fixture.index)
        router.handle(key(KeyEvent.KEYCODE_MEDIA_PREVIOUS,200))
        router.handle(key(KeyEvent.KEYCODE_MEDIA_PREVIOUS,200,KeyEvent.ACTION_UP))
        assertEquals(listOf("next","previous"),fixture.calls)
        assertEquals(1,fixture.index)
        assertFalse(router.handle(key(KeyEvent.KEYCODE_VOLUME_UP,300)))
        fixture.player.release()
    }

    @Test fun mediaButtonIntentSupportsToggleExplicitPlaybackAndIgnoresOtherIntents() {
        val commands=mutableListOf<String>(); var playing=true
        val router=MediaButtonRouter({playing},{commands.add(it)})
        assertFalse(router.handle(Intent("unrelated").putExtra(Intent.EXTRA_KEY_EVENT,key(KeyEvent.KEYCODE_MEDIA_NEXT,100))))
        assertTrue(router.handle(Intent(Intent.ACTION_MEDIA_BUTTON).putExtra(Intent.EXTRA_KEY_EVENT,key(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,200))))
        playing=false
        router.handle(key(KeyEvent.KEYCODE_HEADSETHOOK,300))
        router.handle(key(KeyEvent.KEYCODE_MEDIA_PLAY,400))
        router.handle(key(KeyEvent.KEYCODE_MEDIA_PAUSE,500))
        router.handle(key(KeyEvent.KEYCODE_MEDIA_STOP,600))
        assertEquals(listOf("pause","play","play","pause","stop"),commands)
    }
}
