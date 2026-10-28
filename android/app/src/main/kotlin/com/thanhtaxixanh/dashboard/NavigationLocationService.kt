package com.thanhtaxixanh.dashboard

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class NavigationLocationService : Service(), LocationListener {
    private val state get() = (application as DashboardApplication).navigation
    private val manager get() = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") { (application as DashboardApplication).carLocation.suppress(); stopSelf(); return START_NOT_STICKY }
        val notifications = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notifications.createNotificationChannel(NotificationChannel("navigation", "Vị trí dẫn đường", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 2, Intent(this, NavigationLocationService::class.java).setAction("STOP"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(this, "navigation").setSmallIcon(R.drawable.ic_taxi)
            .setContentTitle("Taxi Xanh · Vị trí đang bật").setContentText("Chạm để mở; Dừng để tắt GPS dẫn đường")
            .setContentIntent(open).setOngoing(true).setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .addAction(R.drawable.ic_home, "Dừng vị trí", stop).build()
        startForeground(404, notification)
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) { state.status = "Chưa cấp quyền vị trí"; state.emit(); stopSelf(); return START_NOT_STICKY }
        try {
            manager.removeUpdates(this)
            if (!manager.isLocationEnabled) { state.status = "Bật GPS trong cài đặt điện thoại"; state.emit(); stopSelf(); return START_NOT_STICKY }
            var enabled = false
            if (fine && manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                manager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, Looper.getMainLooper()); enabled = true
            }
            if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                manager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1000L, 0f, this, Looper.getMainLooper()); enabled = true
            }
            if (!enabled) { state.status = "Chưa có nguồn vị trí"; state.emit(); stopSelf(); return START_NOT_STICKY }
            state.running = true
            state.status = if (fine) "Đang lấy vị trí GPS" else "Chỉ có vị trí gần đúng; bật Vị trí chính xác"
            state.initSpeech(); state.emit()
        } catch (e: Exception) { state.status = "Không khởi động được vị trí; mở lại từ điện thoại"; state.emit(); stopSelf() }
        return START_NOT_STICKY
    }
    override fun onLocationChanged(location: Location) = state.location(location)
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) { state.status = "Nguồn GPS vừa tắt; kiểm tra điện thoại"; state.emit() }
    @Deprecated("Legacy callback") override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    override fun onDestroy() {
        manager.removeUpdates(this)
        state.running = false; state.stop(); state.fix = null; state.emit()
        super.onDestroy()
    }
}
