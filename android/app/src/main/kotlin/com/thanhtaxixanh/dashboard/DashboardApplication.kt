package com.thanhtaxixanh.dashboard

import android.app.Application
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

class DashboardApplication : Application() {
    lateinit var engines: FlutterEngineGroup
    lateinit var diagnostics: Diagnostics
    lateinit var navigation: NavigationState
    override fun onCreate() {
        super.onCreate()
        diagnostics = Diagnostics(this)
        navigation = NavigationState(this)
        engines = FlutterEngineGroup(this)
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
