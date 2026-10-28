package com.thanhtaxixanh.dashboard

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class LocationPermission(private val activity: MainActivity, engine: FlutterEngine) {
    private val methods = MethodChannel(engine.dartExecutor.binaryMessenger, "taxi/location_control")
    private var pending: MethodChannel.Result? = null
    init {
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (pending != null) result.error("BUSY", "Đang xin quyền vị trí", null)
                    else {
                        pending = result
                        val permissions = mutableListOf<String>()
                        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION); permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
                        }
                        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                        if (permissions.isEmpty()) start() else activity.requestPermissions(permissions.toTypedArray(), 4041)
                    }
                }
                "background" -> {
                    val fine = ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    if (!fine) result.error("FINE_FIRST", "Cấp Vị trí chính xác trước, rồi chọn quyền Luôn luôn", null)
                    else if (Build.VERSION.SDK_INT >= 30) {
                        activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${activity.packageName}")))
                        result.success(null)
                    } else {
                        activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), 4042)
                        result.success(null)
                    }
                }
                "settings" -> { activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${activity.packageName}"))); result.success(null) }
                "source" -> { activity.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://www.openstreetmap.org/copyright"))); result.success(null) }
                "installVoice" -> {
                    try { activity.startActivity(Intent(android.speech.tts.TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)); result.success(null) }
                    catch (e: Exception) { result.error("VOICE", "Mở cài đặt Văn bản thành giọng nói để tải giọng Việt", null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun start() {
        val result = pending; pending = null
        val granted = listOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION).any { ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED }
        if (!granted) { result?.error("LOCATION_DENIED", "Cần quyền vị trí. Mở quyền ứng dụng và bật Vị trí chính xác", null); return }
        (activity.application as DashboardApplication).carLocation.manualStart()
        try { ContextCompat.startForegroundService(activity, Intent(activity, NavigationLocationService::class.java)); result?.success(null) }
        catch (e: Exception) { result?.error("LOCATION_START", "Mở ứng dụng điện thoại rồi bật vị trí lại", null) }
    }
    fun permissionResult(request: Int): Boolean { if (request == 4042) { (activity.application as DashboardApplication).carLocation.permissionsChanged(); return true }; if (request != 4041) return false; start(); return true }
    fun close() { pending?.error("CLOSED", "Mở lại màn hình vị trí", null); pending = null; methods.setMethodCallHandler(null) }
}
