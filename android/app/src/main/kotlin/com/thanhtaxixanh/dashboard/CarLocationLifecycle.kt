package com.thanhtaxixanh.dashboard

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.car.app.connection.CarConnection
import androidx.core.content.ContextCompat

// A connection observer, independent of map surfaces/screens: Home, rotation,
// and onSurfaceDestroyed are not Android Auto disconnections.
class CarLocationLifecycle(private val context: Context, private val state: NavigationState) {
    private val connection = CarConnection(context)
    private val handler = Handler(Looper.getMainLooper())
    private var connected = false
    private var seenProjection = false
    private var suppressed = false
    private val disconnected = Runnable {
        if (!connected && seenProjection) {
            context.stopService(Intent(context, NavigationLocationService::class.java))
            state.carConnected = false
            state.status = "Đã tắt vị trí khi Android Auto ngắt kết nối"
            state.emit()
        }
    }
    fun observe() {
        connection.type.observeForever { value ->
            if (value == CarConnection.CONNECTION_TYPE_PROJECTION) {
                handler.removeCallbacks(disconnected)
                val changed = !connected
                connected = true; seenProjection = true; state.carConnected = true
                if (changed) suppressed = false
                ensureLocation()
            } else {
                connected = false
                if (seenProjection) handler.postDelayed(disconnected, 2500)
            }
            state.emit()
        }
    }
    fun sessionVisible() {
        // The app's projected session is a usable fallback while the public
        // connection query is still starting. It never owns disconnect policy.
        state.carConnected = true
        ensureLocation()
    }
    fun permissionsChanged() { if (state.carConnected) ensureLocation() }
    fun suppress() { suppressed = true }
    fun manualStart() { suppressed = false }
    fun userStart() { suppressed = false; ensureLocation(userInitiated = true) }
    private fun ensureLocation(userInitiated: Boolean = false) {
        if (suppressed && !userInitiated || !state.carConnected && !state.phoneVisible || state.running && !userInitiated) return
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) { state.status = "Cấp quyền vị trí trên điện thoại"; state.emit(); return }
        val background = Build.VERSION.SDK_INT < 29 || ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!state.phoneVisible && !background) { state.status = "Bật vị trí trên điện thoại hoặc cho phép Luôn luôn"; state.emit(); return }
        try { ContextCompat.startForegroundService(context, Intent(context, NavigationLocationService::class.java)) }
        catch (e: Exception) { state.status = "Android chưa cho bật GPS nền; mở ứng dụng điện thoại và bấm Bật vị trí"; state.emit() }
    }
}
