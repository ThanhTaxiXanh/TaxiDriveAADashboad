package com.thanhtaxixanh.dashboard

import android.content.Intent
import android.view.KeyEvent
import androidx.core.content.IntentCompat

// Only call for an explicitly delivered media key. Never intercept global keys.
// Reuse one router per playback owner so down/up and repeated downs are consumed
// without changing multiple tracks for one physical press.
class MediaButtonRouter(
    private val isPlaying: () -> Boolean,
    private val dispatch: (String) -> Unit,
) {
    private var lastPress: Triple<Int, Int, Long>? = null

    fun handle(intent: Intent): Boolean {
        if (intent.action != Intent.ACTION_MEDIA_BUTTON) return false
        val event = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_KEY_EVENT, KeyEvent::class.java) ?: return false
        return handle(event)
    }

    fun handle(event: KeyEvent): Boolean {
        val action = when (event.keyCode) {
            KeyEvent.KEYCODE_MEDIA_NEXT -> "next"
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "previous"
            KeyEvent.KEYCODE_MEDIA_PLAY -> "play"
            KeyEvent.KEYCODE_MEDIA_PAUSE -> "pause"
            KeyEvent.KEYCODE_MEDIA_STOP -> "stop"
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_HEADSETHOOK -> if (isPlaying()) "pause" else "play"
            else -> return false
        }
        if (event.action == KeyEvent.ACTION_UP) return true
        if (event.action != KeyEvent.ACTION_DOWN) return false
        if (event.repeatCount > 0 || event.isCanceled) return true
        val press = Triple(event.deviceId, event.keyCode, event.downTime)
        if (press == lastPress) return true
        lastPress = press
        dispatch(action)
        return true
    }
}
