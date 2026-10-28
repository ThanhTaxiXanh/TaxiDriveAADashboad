package com.thanhtaxixanh.dashboard

import android.app.Application
import android.net.http.HttpResponseCache
import java.io.File
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

class DashboardApplication : Application() {
    lateinit var engines: FlutterEngineGroup
    lateinit var diagnostics: Diagnostics
    lateinit var navigation: NavigationState
    lateinit var carLocation: CarLocationLifecycle
    override fun onCreate() {
        super.onCreate()
        // Native MapLibre uses HttpURLConnection. Keep normal viewport HTTP
        // responses private and bounded; no offline region prefetch.
        try { HttpResponseCache.install(File(cacheDir, "map-http"), 300L * 1024 * 1024) } catch (_: java.io.IOException) {}
        diagnostics = Diagnostics(this)
        navigation = NavigationState(this)
        engines = FlutterEngineGroup(this)
        carLocation = CarLocationLifecycle(this, navigation)
        carLocation.observe()
    }
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        HttpResponseCache.getInstalled()?.flush()
    }
    fun engine(entrypoint: String): FlutterEngine {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)
        return engines.createAndRunEngine(
            this, DartExecutor.DartEntrypoint(loader.findAppBundlePath(), entrypoint)
        )
    }
}
