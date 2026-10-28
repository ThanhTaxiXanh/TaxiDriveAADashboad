package com.thanhtaxixanh.dashboard

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File

class MainActivity : FlutterActivity() {
    private var bridge: DashboardBridge? = null
    private var calendarFiles: CalendarFiles? = null
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as DashboardApplication).engine("main")
    override fun shouldDestroyEngineWithHost() = true
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        calendarFiles = CalendarFiles(this, flutterEngine)
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
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (calendarFiles?.activityResult(requestCode, resultCode, data) != true) super.onActivityResult(requestCode, resultCode, data)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        calendarFiles?.close(); calendarFiles = null
        bridge?.close()
        bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
