package app.orbit.orbit_visual_lab

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.ConcurrentHashMap

/** Owns native views by Flutter platform-view id. No renderer is global or shared. */
object FilamentViewRegistry {
    private val views = ConcurrentHashMap<Int, FilamentPlatformView>()

    fun register(view: FilamentPlatformView) {
        views[view.viewId] = view
    }

    fun unregister(viewId: Int) {
        views.remove(viewId)
    }

    fun configure(
        viewId: Int,
        profile: String,
        quality: String,
        paused: Boolean,
        atmosphereMode: String = "automatic",
    ): Map<String, Any?> {
        val view = views[viewId]
            ?: return mapOf(
                "initialized" to false,
                "lastError" to "Native Filament view $viewId is unavailable",
            )
        view.configure(profile, quality, paused, atmosphereMode)
        return view.stats()
    }

    fun parallax(viewId: Int, x: Float, y: Float) {
        views[viewId]?.setParallax(x, y)
    }

    fun release(viewId: Int) {
        views.remove(viewId)?.release()
        android.util.Log.i("ORBIT_FILAMENT", "activeViews=${views.size} releaseId=$viewId")
    }

    fun pauseAll() = views.values.forEach { it.setActivityPaused(true) }

    fun resumeAll() = views.values.forEach { it.setActivityPaused(false) }

    fun lowMemory() {
        views.values.toList().forEach {
            it.signalFailure("Android low-memory signal: native scene released")
            it.release()
        }
        android.util.Log.i("ORBIT_FILAMENT", "activeViews=${views.size} reason=lowMemory")
    }

    fun releaseAll() {
        views.values.toList().forEach { it.release() }
        android.util.Log.i("ORBIT_FILAMENT", "activeViews=${views.size} reason=releaseAll")
    }

    fun stats(viewId: Int): Map<String, Any?> = views[viewId]?.stats() ?: mapOf(
        "initialized" to false,
        "sceneReady" to false,
        "hasSwapChain" to false,
        "renderedFrames" to 0L,
        "lastError" to "Native Filament view $viewId is unavailable",
    )

    fun stats(): Map<String, Any?> = views.values.associate { view ->
        view.viewId.toString() to view.stats()
    }
}

class FilamentViewFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val view = FilamentPlatformView(
            activity = activity,
            messenger = messenger,
            viewId = viewId,
            initialProfile = params?.get("profile") as? String ?: "one",
            initialQuality = params?.get("quality") as? String ?: "balanced",
            initialAtmosphereMode = params?.get("atmosphereMode") as? String ?: "automatic",
        )
        FilamentViewRegistry.register(view)
        return view
    }
}
