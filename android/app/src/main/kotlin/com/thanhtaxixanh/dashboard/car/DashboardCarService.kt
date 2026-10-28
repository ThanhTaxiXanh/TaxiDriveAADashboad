package com.thanhtaxixanh.dashboard.car

import android.content.Intent
import android.content.res.Configuration
import android.graphics.Rect
import androidx.car.app.AppManager
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.validation.HostValidator
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.thanhtaxixanh.dashboard.DashboardApplication
import com.thanhtaxixanh.dashboard.R

class DashboardCarService : CarAppService() {
    // Personal sideload spike: intentionally accepts hosts, not a Play distribution build.
    override fun createHostValidator(): HostValidator = HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    override fun onCreateSession(): Session = object : Session() {
        override fun onCreateScreen(intent: Intent): Screen = SpikeScreen(carContext)
        override fun onCarConfigurationChanged(newConfiguration: Configuration) {
            super.onCarConfigurationChanged(newConfiguration)
            (carContext.applicationContext as DashboardApplication).diagnostics.update("carDark" to carContext.isDarkMode)
        }
    }
}

private class SpikeScreen(context: CarContext) : Screen(context), SurfaceCallback {
    private val renderer = SurfaceRenderer(context)
    init {
        (context.applicationContext as DashboardApplication).diagnostics.update("carApi" to context.carAppApiLevel, "carDark" to context.isDarkMode, "panel" to "dashboard")
        context.getCarService(AppManager::class.java).setSurfaceCallback(this)
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) {
                context.getCarService(AppManager::class.java).setSurfaceCallback(null)
                renderer.release()
            }
        })
    }
    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) = renderer.attach(surfaceContainer)
    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) = renderer.release()
    override fun onVisibleAreaChanged(visibleArea: Rect) = renderer.visible(visibleArea)
    override fun onClick(x: Float, y: Float) = renderer.click(x, y)
    override fun onScroll(distanceX: Float, distanceY: Float) = renderer.scroll(distanceX, distanceY)

    override fun onGetTemplate(): Template {
        fun action(icon: Int, panel: String? = null): Action = Action.Builder()
            .setIcon(CarIcon.Builder(IconCompat.createWithResource(carContext, icon)).build())
            .setOnClickListener {
                val state = (carContext.applicationContext as DashboardApplication).diagnostics
                state.update("panel" to (panel ?: "dashboard"))
                if (panel == null) carContext.finishCarApp()
            }.build()
        return NavigationTemplate.Builder()
            .setActionStrip(ActionStrip.Builder()
                .addAction(action(R.drawable.ic_home))
                .addAction(action(R.drawable.ic_youtube, "youtube"))
                .addAction(action(R.drawable.ic_settings, "settings"))
                .addAction(action(R.drawable.ic_plus, "modules")).build())
            .setMapActionStrip(ActionStrip.Builder().addAction(Action.PAN).build())
            .build()
    }
}
