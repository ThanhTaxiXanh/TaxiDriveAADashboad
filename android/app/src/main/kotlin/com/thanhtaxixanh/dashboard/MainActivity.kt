package com.thanhtaxixanh.dashboard

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File

class MainActivity : FlutterActivity() {
    private var bridge: DashboardBridge? = null
    private var locationPermission: LocationPermission? = null
    private var roadFiles: CalendarFiles? = null
    private var calendarFiles: CalendarFiles? = null
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as DashboardApplication).engine("main")
    override fun shouldDestroyEngineWithHost() = true
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        calendarFiles = CalendarFiles(this, flutterEngine)
        roadFiles = CalendarFiles(this, flutterEngine, road = true)
        locationPermission = LocationPermission(this, flutterEngine)
        bridge = DashboardBridge(flutterEngine, (application as DashboardApplication).diagnostics) {
            val folder = File(cacheDir, "shared-logs").apply { mkdirs() }
            val target = File(folder, "dashboard-diagnostics.txt")
            target.writeText((application as DashboardApplication).diagnostics.export())
            val uri = FileProvider.getUriForFile(this, "$packageName.logs", target)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(send, "Chia sẻ nhật ký"))
        }
    }
    override fun onResume() {
        super.onResume()
        val state = (application as DashboardApplication).navigation
        state.phoneVisible = true
        state.emit()
        (application as DashboardApplication).carLocation.permissionsChanged()
        (application as DashboardApplication).media.external.refresh()
        if (state.running) state.initSpeech()
    }
    override fun onPause() {
        (application as DashboardApplication).navigation.phoneVisible = false
        super.onPause()
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (calendarFiles?.activityResult(requestCode, resultCode, data) != true && roadFiles?.activityResult(requestCode, resultCode, data) != true) super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (locationPermission?.permissionResult(requestCode) != true) super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        locationPermission?.close(); locationPermission = null
        calendarFiles?.close(); calendarFiles = null
        roadFiles?.close(); roadFiles = null
        bridge?.close()
        bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
