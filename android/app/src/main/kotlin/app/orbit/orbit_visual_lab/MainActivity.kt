package app.orbit.orbit_visual_lab

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var systemChannel: MethodChannel
    private lateinit var qaExportManager: QaExportManager
    private var lowMemory = false
    private var lastFilamentStatsLog = 0L

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var motionSensorManager: SensorManager? = null
    private var motionEventListener: SensorEventListener? = null
    private var motionEventSink: EventChannel.EventSink? = null

    private var nativeSensorType: String = "none"
    private var nativeListenerRegistered: Boolean = false
    private var nativeSensorEventCount: Long = 0L
    private var lastNativeSensorEventMs: Long = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "orbit/filament_scene",
            FilamentViewFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit/filament")
            .setMethodCallHandler { call, result ->
                val args = call.arguments as? Map<*, *>
                val viewId = args?.get("id") as? Int
                when {
                    call.method == "configure" && viewId != null -> {
                        result.success(
                            FilamentViewRegistry.configure(
                                viewId = viewId,
                                profile = args["profile"] as? String ?: "one",
                                quality = args["quality"] as? String ?: "balanced",
                                paused = args["paused"] as? Boolean ?: false,
                                atmosphereMode = args["atmosphereMode"] as? String ?: "automatic",
                            ),
                        )
                    }
                    call.method == "release" && viewId != null -> {
                        FilamentViewRegistry.release(viewId)
                        result.success(null)
                    }
                    call.method == "parallax" && viewId != null -> {
                        FilamentViewRegistry.parallax(
                            viewId,
                            (args["x"] as? Number)?.toFloat() ?: 0f,
                            (args["y"] as? Number)?.toFloat() ?: 0f,
                        )
                        result.success(null)
                    }
                    call.method == "stats" && viewId != null -> {
                        val stats = FilamentViewRegistry.stats(viewId)
                        val now = SystemClock.elapsedRealtime()
                        if (now - lastFilamentStatsLog >= 5000) {
                            lastFilamentStatsLog = now
                            Log.i("ORBIT_FILAMENT", "activeViews=${FilamentViewRegistry.stats().size} stats=$stats")
                        }
                        result.success(stats)
                    }
                    call.method == "stats" -> result.success(FilamentViewRegistry.stats())
                    else -> result.notImplemented()
                }
            }

        qaExportManager = QaExportManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit/qa")
            .setMethodCallHandler { call, result ->
                qaExportManager.handle(
                    call.method,
                    call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                    result,
                )
            }

        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "orbit/system",
        )
        systemChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemInfo" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    result.success(
                        mapOf(
                            "supportedAbis" to android.os.Build.SUPPORTED_ABIS.toList(),
                            "isDebug" to ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0),
                            "versionName" to (info.versionName ?: "unknown"),
                            "versionCode" to info.longVersionCode,
                            "buildFlavor" to BuildConfig.ORBIT_BUILD_FLAVOR,
                            "gitHash" to BuildConfig.ORBIT_GIT_HASH,
                            "nativeSensorType" to nativeSensorType,
                            "nativeListenerRegistered" to nativeListenerRegistered,
                            "nativeSensorEventCount" to nativeSensorEventCount,
                            "lastNativeSensorEventMs" to lastNativeSensorEventMs,
                        ),
                    )
                }
                "getSensorDiagnostics" -> {
                    result.success(
                        mapOf(
                            "nativeSensorType" to nativeSensorType,
                            "nativeListenerRegistered" to nativeListenerRegistered,
                            "nativeSensorEventCount" to nativeSensorEventCount,
                            "lastNativeSensorEventMs" to lastNativeSensorEventMs,
                        ),
                    )
                }
                "refreshSystemStatus" -> {
                    sendPowerSaveStatus()
                    result.success(null)
                }
                "checkStoragePermission" -> {
                    val granted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        checkSelfPermission(android.Manifest.permission.READ_MEDIA_IMAGES) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    } else {
                        checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    }
                    result.success(granted)
                }
                "requestStoragePermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(arrayOf(android.Manifest.permission.READ_MEDIA_IMAGES), 101)
                    } else {
                        requestPermissions(arrayOf(android.Manifest.permission.READ_EXTERNAL_STORAGE), 101)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        motionSensorManager = getSystemService(SENSOR_SERVICE) as? SensorManager
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "orbit/motion")
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        motionEventSink = events
                        startMotionUpdates()
                    }

                    override fun onCancel(arguments: Any?) {
                        stopMotionUpdates()
                        motionEventSink = null
                    }
                },
            )
    }

    private fun startMotionUpdates() {
        if (motionEventListener != null || motionSensorManager == null) return
        val sensor = motionSensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: motionSensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: motionSensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        if (sensor == null) {
            nativeSensorType = "NONE"
            nativeListenerRegistered = false
            Log.w("ORBIT_MOTION", "No motion sensor found on device")
            mainHandler.post {
                motionEventSink?.error("NO_SENSOR", "No motion sensor found on device", null)
            }
            return
        }

        nativeSensorType = when (sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> "ROTATION_VECTOR"
            Sensor.TYPE_GRAVITY -> "GRAVITY"
            Sensor.TYPE_ACCELEROMETER -> "ACCELEROMETER"
            else -> sensor.name
        }

        val isRotation = sensor.type == Sensor.TYPE_ROTATION_VECTOR
        motionEventListener = object : SensorEventListener {
            private val rotationMatrix = FloatArray(9)
            private val orientation = FloatArray(3)

            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null || motionEventSink == null) return
                nativeSensorEventCount++
                lastNativeSensorEventMs = SystemClock.elapsedRealtime()

                if (isRotation) {
                    val vector = if (event.values.size > 4) {
                        floatArrayOf(event.values[0], event.values[1], event.values[2], event.values[3])
                    } else {
                        event.values
                    }
                    try {
                        SensorManager.getRotationMatrixFromVector(rotationMatrix, vector)
                    } catch (e: Exception) {
                        return
                    }
                    val rotation = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        display?.rotation ?: android.view.Surface.ROTATION_0
                    } else {
                        @Suppress("DEPRECATION")
                        windowManager.defaultDisplay.rotation
                    }
                    val remappedMatrix = FloatArray(9)
                    when (rotation) {
                        android.view.Surface.ROTATION_90 -> {
                            SensorManager.remapCoordinateSystem(
                                rotationMatrix,
                                SensorManager.AXIS_Y,
                                SensorManager.AXIS_MINUS_X,
                                remappedMatrix,
                            )
                        }
                        android.view.Surface.ROTATION_180 -> {
                            SensorManager.remapCoordinateSystem(
                                rotationMatrix,
                                SensorManager.AXIS_MINUS_X,
                                SensorManager.AXIS_MINUS_Y,
                                remappedMatrix,
                            )
                        }
                        android.view.Surface.ROTATION_270 -> {
                            SensorManager.remapCoordinateSystem(
                                rotationMatrix,
                                SensorManager.AXIS_MINUS_Y,
                                SensorManager.AXIS_X,
                                remappedMatrix,
                            )
                        }
                        else -> {
                            System.arraycopy(rotationMatrix, 0, remappedMatrix, 0, 9)
                        }
                    }
                    SensorManager.getOrientation(remappedMatrix, orientation)
                    // orientation[2] is roll (-pi to pi), orientation[1] is pitch (-pi/2 to pi/2)
                    // ~10-12 degrees (0.20 radians) gives full ±1.0 amplitude for clearly visible response
                    val roll = (orientation[2] / 0.20f).coerceIn(-1.0f, 1.0f)
                    val pitch = (orientation[1] / 0.20f).coerceIn(-1.0f, 1.0f)
                    val outData = doubleArrayOf(roll.toDouble(), pitch.toDouble())
                    mainHandler.post {
                        motionEventSink?.success(outData)
                    }
                } else {
                    // Gravity or accelerometer: values[0] is X, values[1] is Y
                    val normX = (event.values[0] / 3.0f).coerceIn(-1.0f, 1.0f)
                    val normY = (event.values[1] / 3.0f).coerceIn(-1.0f, 1.0f)
                    val outData = doubleArrayOf(-normX.toDouble(), normY.toDouble())
                    mainHandler.post {
                        motionEventSink?.success(outData)
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        val registered = motionSensorManager?.registerListener(
            motionEventListener,
            sensor,
            SensorManager.SENSOR_DELAY_UI,
        ) ?: false
        nativeListenerRegistered = registered
        Log.i("ORBIT_MOTION", "Sensor listener registered=$registered, type=$nativeSensorType")
    }

    private fun stopMotionUpdates() {
        motionEventListener?.let {
            motionSensorManager?.unregisterListener(it)
            motionEventListener = null
        }
        nativeListenerRegistered = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawableResource(R.drawable.launch_background)
    }

    override fun onResume() {
        super.onResume()
        FilamentViewRegistry.resumeAll()
        if (::systemChannel.isInitialized) sendPowerSaveStatus()
        if (motionEventSink != null) startMotionUpdates()
    }

    override fun onPause() {
        stopMotionUpdates()
        FilamentViewRegistry.pauseAll()
        super.onPause()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (!::systemChannel.isInitialized) return
        if (level >= TRIM_MEMORY_MODERATE) {
            lowMemory = true
            systemChannel.invokeMethod("lowMemory", null)
            FilamentViewRegistry.lowMemory()
        } else if (lowMemory) {
            lowMemory = false
            systemChannel.invokeMethod("memoryRecovered", null)
        }
    }

    override fun onDestroy() {
        FilamentViewRegistry.releaseAll()
        super.onDestroy()
    }

    private fun sendPowerSaveStatus() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        systemChannel.invokeMethod("powerSaveMode", powerManager.isPowerSaveMode)
    }
}
