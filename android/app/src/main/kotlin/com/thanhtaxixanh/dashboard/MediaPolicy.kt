package com.thanhtaxixanh.dashboard

// The native player enforces this independently of both Flutter UIs.
object MediaPolicy {
    fun videoAllowed(running: Boolean, ageMs: Long, accuracy: Double, speedKmh: Double): Boolean =
        running && ageMs in 0..10000 && accuracy.isFinite() && accuracy in 0.0..30.0 &&
            speedKmh.isFinite() && speedKmh >= 0 && speedKmh < 5.0

    fun position(base: Long, updatedMs: Long, nowMs: Long, speed: Float, playing: Boolean, duration: Long): Long {
        val elapsed = (nowMs - updatedMs).coerceIn(0, 86400000)
        val value = base.coerceAtLeast(0) + if (playing && speed.isFinite()) (elapsed * speed.coerceAtLeast(0f)).toLong() else 0
        return if (duration > 0) value.coerceIn(0, duration) else value.coerceAtLeast(0)
    }
}
