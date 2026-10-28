package com.thanhtaxixanh.dashboard.car

import android.app.Presentation
import android.content.Context
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import android.view.WindowManager
import androidx.car.app.SurfaceContainer
import com.thanhtaxixanh.dashboard.DashboardApplication
import com.thanhtaxixanh.dashboard.DashboardBridge
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener

class SurfaceRenderer(private val context: Context) {
    private val app = context.applicationContext as DashboardApplication
    private val state = app.diagnostics
    private var display: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var view: FlutterView? = null
    private var engine: FlutterEngine? = null
    private var bridge: DashboardBridge? = null
    private var current: SurfaceContainer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var dragTime = 0L
    private var dragX = 0f
    private var dragY = 0f
    private val endDrag = Runnable { finishDrag(MotionEvent.ACTION_UP) }
    private fun dispatch(action: Int) {
        val event = MotionEvent.obtain(dragTime, SystemClock.uptimeMillis(), action, dragX, dragY, 0)
        event.source = InputDevice.SOURCE_TOUCHSCREEN
        try { view?.dispatchTouchEvent(event) } finally { event.recycle() }
    }
    private fun finishDrag(action: Int) {
        handler.removeCallbacks(endDrag)
        if (dragTime != 0L) { dispatch(action); dragTime = 0L }
    }
    fun scroll(dx: Float, dy: Float) {
        val surface = current ?: return
        if (!dx.isFinite() || !dy.isFinite() || view == null) return
        handler.removeCallbacks(endDrag)
        if (dragTime == 0L) {
            dragTime = SystemClock.uptimeMillis()
            dragX = surface.width / 2f; dragY = surface.height / 2f
            dispatch(MotionEvent.ACTION_DOWN)
        }
        dragX = (dragX - dx).coerceIn(0f, surface.width.toFloat() - 1)
        dragY = (dragY - dy).coerceIn(0f, surface.height.toFloat() - 1)
        dispatch(MotionEvent.ACTION_MOVE)
        handler.postDelayed(endDrag, 160)
    }

    fun attach(container: SurfaceContainer) {
        release()
        val surface = container.surface ?: return
        if (!surface.isValid || container.width <= 0 || container.height <= 0) return
        current = container
        state.update("surface" to true, "width" to container.width,
            "height" to container.height, "dpi" to container.dpi,
            "firstFrame" to false, "fps" to 0.0, "error" to "Không",
            "visible" to listOf(0, 0, 0, 0))
        try {
            val manager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            display = manager.createVirtualDisplay(
                "TaxiXanhFlutter", container.width, container.height, container.dpi.coerceAtLeast(120),
                surface, DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY
            ) ?: error("VirtualDisplay unavailable")
            val flutter = app.engine("carMain")
            engine = flutter
            bridge = DashboardBridge(flutter, state)
            flutter.renderer.addIsDisplayingFlutterUiListener(object : FlutterUiDisplayListener {
                override fun onFlutterUiDisplayed() { state.update("firstFrame" to true) }
                override fun onFlutterUiNoLongerDisplayed() {}
            })
            presentation = object : Presentation(context, display!!.display) {
                override fun onCreate(savedInstanceState: Bundle?) {
                    super.onCreate(savedInstanceState)
                    window?.setFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
                    view = FlutterView(getContext(), FlutterTextureView(getContext())).also {
                        setContentView(it)
                        it.attachToFlutterEngine(flutter)
                    }
                }
            }.also { it.show() }
            flutter.lifecycleChannel.appIsResumed()
        } catch (e: Exception) {
            release()
            state.update("error" to "SurfaceRenderer: ${e.javaClass.simpleName}")
        }
    }

    fun visible(rect: Rect) {
        val surface = current ?: return
        if (rect.isEmpty) return
        state.update("visible" to listOf(
            rect.left.coerceIn(0, surface.width), rect.top.coerceIn(0, surface.height),
            (surface.width - rect.right).coerceIn(0, surface.width),
            (surface.height - rect.bottom).coerceIn(0, surface.height)))
    }

    // Host coordinates are physical surface pixels; the view fills the same display.
    fun click(x: Float, y: Float) {
        finishDrag(MotionEvent.ACTION_CANCEL)
        val target = view ?: return
        val surface = current ?: return
        if (!x.isFinite() || !y.isFinite() || x < 0 || y < 0 || x >= surface.width || y >= surface.height) return
        val now = SystemClock.uptimeMillis()
        for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
            val event = MotionEvent.obtain(now, now + if (action == MotionEvent.ACTION_UP) 16 else 0,
                action, x, y, 0)
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            try { target.dispatchTouchEvent(event) } finally { event.recycle() }
        }
        state.update("touches" to ((state.values["touches"] as Int) + 1))
    }

    fun release() {
        finishDrag(MotionEvent.ACTION_CANCEL)
        view?.detachFromFlutterEngine()
        view = null
        presentation?.dismiss(); presentation = null
        bridge?.close(); bridge = null
        engine?.lifecycleChannel?.appIsDetached()
        engine?.destroy(); engine = null
        display?.release(); display = null
        // The host owns Surface; never call Surface.release().
        current = null
        state.update("surface" to false, "firstFrame" to false, "fps" to 0.0)
    }
}
