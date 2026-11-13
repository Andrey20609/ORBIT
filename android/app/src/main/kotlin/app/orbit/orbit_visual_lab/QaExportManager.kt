package app.orbit.orbit_visual_lab

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import android.view.PixelCopy
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Explicit, local-only diagnostics capture. This class has no network code. */
class QaExportManager(private val activity: Activity) {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun handle(call: String, args: Map<*, *>, result: MethodChannel.Result) {
        when (call) {
            "captureWindow" -> captureWindow(args, result)
            "exportQa" -> {
                try {
                    result.success(exportQa(args))
                } catch (error: Throwable) {
                    Log.e(TAG, "QA export failed", error)
                    result.error("QA_EXPORT_FAILED", error.message, null)
                }
            }
            "shareQa" -> {
                try {
                    shareQa(args["path"] as? String ?: error("Missing QA path"))
                    result.success(null)
                } catch (error: Throwable) {
                    result.error("QA_SHARE_FAILED", error.message, null)
                }
            }
            "saveScreenshot" -> {
                try {
                    result.success(saveScreenshot(args))
                } catch (error: Throwable) {
                    result.error("QA_SCREENSHOT_FAILED", error.message, null)
                }
            }
            "exportText" -> {
                try {
                    result.success(exportText(args))
                } catch (error: Throwable) {
                    result.error("QA_TEXT_EXPORT_FAILED", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun saveScreenshot(args: Map<*, *>): Map<String, Any?> {
        val name = safeName(args["name"] as? String ?: "capture")
        val bytes = args["bytes"] as? ByteArray ?: error("Missing screenshot bytes")
        require(bytes.isNotEmpty()) { "Screenshot is empty" }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val output = File(captureRoot(), "$name.png")
            output.writeBytes(bytes)
            return mapOf("path" to output.absolutePath, "bytes" to output.length())
        }
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, "$name.png")
            put(MediaStore.Downloads.MIME_TYPE, "image/png")
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/ORBIT_0.5.4")
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("MediaStore insert failed")
        resolver.openOutputStream(uri, "w")?.use { stream ->
            stream.write(bytes)
            stream.flush()
        } ?: error("MediaStore output stream failed")
        return mapOf("uri" to uri.toString(), "bytes" to bytes.size)
    }

    private fun exportText(args: Map<*, *>): String {
        val name = safeName(args["name"] as? String ?: "backup")
        val directoryName = safeName(args["directory"] as? String ?: "ORBIT_recovery")
        val text = args["text"] as? String ?: error("Missing backup text")
        val parent = activity.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
        val directory = File(parent, directoryName).apply { mkdirs() }
        val output = File(directory, "${timestamp()}_$name.txt")
        output.writeText(text, Charsets.UTF_8)
        return output.absolutePath
    }

    private fun captureWindow(args: Map<*, *>, result: MethodChannel.Result) {
        val name = safeName(args["name"] as? String ?: "capture")
        val requested = args["requestedRenderer"] as? String ?: name
        val directory = File(captureRoot(), "${timestamp()}_$name").apply { mkdirs() }
        val output = File(directory, "$name.png")
        val view = activity.window.decorView
        if (view.width <= 0 || view.height <= 0) {
            result.error("QA_CAPTURE_FAILED", "Window has no drawable dimensions", null)
            return
        }
        val completed = java.util.concurrent.atomic.AtomicBoolean(false)
        fun reportError(message: String?) {
            if (completed.compareAndSet(false, true)) {
                Log.w(TAG, "Capture $name failed: $message")
                result.error("QA_CAPTURE_FAILED", message, null)
            }
        }
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            try {
                Canvas(bitmap).let { view.draw(it) }
                writePng(bitmap, output)
                if (completed.compareAndSet(false, true)) {
                    result.success(captureResult(output, requested, "View.draw", bitmap))
                }
            } catch (error: Throwable) {
                reportError(error.message)
            }
            return
        }
        mainHandler.postDelayed(
            { reportError("PixelCopy.window timed out after 10000 ms") },
            10_000,
        )
        try {
            PixelCopy.request(
                activity.window,
                bitmap,
                { copyResult ->
                    if (copyResult != PixelCopy.SUCCESS) {
                        reportError("PixelCopy result=$copyResult")
                        return@request
                    }
                    if (!completed.compareAndSet(false, true)) return@request
                    try {
                        writePng(bitmap, output)
                        result.success(captureResult(output, requested, "PixelCopy.window", bitmap))
                    } catch (pixelCopyError: Throwable) {
                        try {
                            val fallback = Bitmap.createBitmap(
                                view.width,
                                view.height,
                                Bitmap.Config.ARGB_8888,
                            )
                            Canvas(fallback).let { view.draw(it) }
                            writePng(fallback, output)
                            result.success(
                                captureResult(output, requested, "View.draw.fallback", fallback),
                            )
                        } catch (fallbackError: Throwable) {
                            result.error(
                                "QA_CAPTURE_FAILED",
                                "PixelCopy: ${pixelCopyError.message}; View.draw: ${fallbackError.message}",
                                null,
                            )
                        }
                    }
                },
                mainHandler,
            )
        } catch (error: Throwable) {
            reportError(error.message)
        }
    }

    private fun captureResult(
        output: File,
        requested: String,
        method: String,
        bitmap: Bitmap,
    ): Map<String, Any?> {
        val stats = pixelStats(bitmap)
        require(stats.opaqueFraction >= 0.001 && stats.colorBins >= 2 && stats.lumaVariance > 0.0) {
            "Capture is transparent or visually empty: $stats"
        }
        return mapOf(
            "path" to output.absolutePath,
            "requestedRenderer" to requested,
            "captureMethod" to method,
            "width" to bitmap.width,
            "height" to bitmap.height,
            "sha256" to sha256(output),
            "opaqueFraction" to stats.opaqueFraction,
            "colorBins" to stats.colorBins,
            "lumaVariance" to stats.lumaVariance,
        )
    }

    private data class PixelStats(
        val opaqueFraction: Double,
        val colorBins: Int,
        val lumaVariance: Double,
    )

    private fun pixelStats(bitmap: Bitmap): PixelStats {
        val stepX = (bitmap.width / 96).coerceAtLeast(1)
        val stepY = (bitmap.height / 96).coerceAtLeast(1)
        val bins = mutableSetOf<Int>()
        val luminance = mutableListOf<Double>()
        var opaque = 0
        var samples = 0
        var y = 0
        while (y < bitmap.height) {
            var x = 0
            while (x < bitmap.width) {
                val pixel = bitmap.getPixel(x, y)
                val alpha = (pixel ushr 24) and 0xFF
                if (alpha > 0) opaque++
                val red = (pixel ushr 16) and 0xFF
                val green = (pixel ushr 8) and 0xFF
                val blue = pixel and 0xFF
                bins += ((red shr 4) shl 8) or ((green shr 4) shl 4) or (blue shr 4)
                luminance += 0.2126 * red + 0.7152 * green + 0.0722 * blue
                samples++
                x += stepX
            }
            y += stepY
        }
        val mean = luminance.average()
        val variance = luminance.map { value -> (value - mean) * (value - mean) }.average()
        return PixelStats(opaque.toDouble() / samples, bins.size, variance)
    }

    private fun writePng(bitmap: Bitmap, output: File) {
        FileOutputStream(output).use { stream ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                error("PNG encoder returned false")
            }
            stream.flush()
        }
    }

    private fun exportQa(args: Map<*, *>): Map<String, Any?> {
        @Suppress("UNCHECKED_CAST")
        val captures = args["captures"] as? List<Map<*, *>>
            ?: error("Three capture records are required")
        require(captures.size == 3) { "Exactly three PNG captures are required" }
        val exportDirectory = File(exportRoot(), "ORBIT_QA_${timestamp()}").apply { mkdirs() }
        val screenshots = File(exportDirectory, "screenshots").apply { mkdirs() }
        val manifestCaptures = JSONArray()
        val files = mutableListOf<File>()

        captures.forEachIndexed { index, capture ->
            val source = File(capture["path"] as? String ?: error("Missing capture path"))
            require(source.isFile) { "Capture does not exist: ${source.name}" }
            require(source.extension.equals("png", ignoreCase = true)) { "Capture is not PNG" }
            val requested = safeName(capture["requestedRenderer"] as? String ?: "renderer_$index")
            val destination = File(screenshots, "$requested.png")
            source.inputStream().use { input ->
                FileOutputStream(destination).use { output -> input.copyTo(output) }
            }
            files += destination
            manifestCaptures.put(JSONObject().apply {
                put("requestedRenderer", requested)
                put("actualRenderer", capture["actualRenderer"]?.toString() ?: "unknown")
                put("captureMethod", capture["captureMethod"]?.toString() ?: "unknown")
                put("width", capture["width"] as? Number ?: 0)
                put("height", capture["height"] as? Number ?: 0)
                put("file", "screenshots/$requested.png")
                put("sha256", sha256(destination))
            })
        }

        files += writeJson(
            File(exportDirectory, "device_info.json"),
            JSONObject().apply {
                put("manufacturer", Build.MANUFACTURER)
                put("model", Build.MODEL)
                put("device", Build.DEVICE)
                put("androidRelease", Build.VERSION.RELEASE)
                put("sdkInt", Build.VERSION.SDK_INT)
                put("supportedAbis", JSONArray(Build.SUPPORTED_ABIS.toList()))
                put("demoDataOnly", true)
                // Deliberately no serial number, account, ANDROID_ID or location.
            },
        )
        files += writeJson(
            File(exportDirectory, "build_info.json"),
            JSONObject().apply {
                put("applicationId", activity.packageName)
                put("versionName", packageInfo("versionName"))
                put("versionCode", packageInfo("versionCode"))
                put("buildType", "debug")
                put("captureUtc", timestamp())
            },
        )
        files += writeRawJson(
            File(exportDirectory, "settings.json"),
            args["settingsJson"] as? String ?: "{}",
        )
        files += writeRawJson(
            File(exportDirectory, "runtime_stats.json"),
            args["runtimeStatsJson"] as? String ?: "{}",
        )
        files += writeRawJson(
            File(exportDirectory, "checks.json"),
            args["checksJson"] as? String ?: "{}",
        )
        files += File(exportDirectory, "logcat.txt").apply {
            writeText(filteredLogcat())
        }
        files += writeJson(
            File(exportDirectory, "capture_manifest.json"),
            JSONObject().apply {
                put("schemaVersion", 1)
                put("userInitiated", true)
                put("externalUpload", false)
                put("captures", manifestCaptures)
                put("nativeFilamentStats", JSONObject(FilamentViewRegistry.stats()))
            },
        )
        files += File(exportDirectory, "README.txt").apply {
            writeText(
                "ORBIT Visual Lab — explicit local QA capture\n" +
                    "Demo data only. No mail/server connection and no external upload.\n" +
                    "The three PNGs show the requested renderer and its recorded actual renderer.\n" +
                    "A Static actual renderer is a fallback, never proof of native Filament/Rive.\n" +
                    "Performance, reboot and upgrade checks are NOT RUN unless raw results say otherwise.\n",
            )
        }
        val checksums = File(exportDirectory, "SHA256SUMS.txt")
        checksums.writeText(
            files.sortedBy { it.name }.joinToString("\n") {
                "${sha256(it)}  ${it.relativeTo(exportDirectory).path}"
            } + "\n",
        )
        files += checksums

        val zip = File(exportRoot(), "${exportDirectory.name}.zip")
        ZipOutputStream(FileOutputStream(zip).buffered()).use { archive ->
            files.sortedBy { it.relativeTo(exportDirectory).path }.forEach { file ->
                archive.putNextEntry(ZipEntry(file.relativeTo(exportDirectory).path))
                FileInputStream(file).use { input -> input.copyTo(archive) }
                archive.closeEntry()
            }
        }
        return mapOf(
            "path" to zip.absolutePath,
            "sha256" to sha256(zip),
            "bytes" to zip.length(),
            "externalUpload" to false,
        )
    }

    private fun filteredLogcat(): String {
        val header = "Filtered app-process logcat; secrets and email-like strings redacted.\n"
        val output = StringBuilder(header)
        try {
            val process = Runtime.getRuntime().exec(
                arrayOf("logcat", "-d", "-v", "threadtime", "--pid=${Process.myPid()}", "-t", "1200"),
            )
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                reader.lineSequence()
                    .filter { line ->
                        line.contains("ORBIT", true) ||
                            line.contains("Filament", true) ||
                            line.contains("Rive", true) ||
                            line.contains("flutter", true) ||
                            line.contains("AndroidRuntime", true) ||
                            line.contains(activity.packageName, true)
                    }
                    .toList()
                    .takeLast(800)
                    .forEach { line -> output.appendLine(redact(line)) }
            }
            process.waitFor()
        } catch (error: Throwable) {
            output.appendLine("Logcat unavailable: ${redact(error.message ?: error.javaClass.simpleName)}")
        }
        return output.toString()
    }

    private fun redact(value: String): String {
        var result = value.replace(
            Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"),
            "[REDACTED_EMAIL]",
        )
        result = result.replace(
            Regex("(?i)(token|password|passwd|authorization|api[_-]?key|secret)=?[^ ,;]+"),
            "${'$'}1=[REDACTED]",
        )
        result = result.replace(Regex("Bearer\\s+[A-Za-z0-9._~+/=-]+", RegexOption.IGNORE_CASE), "Bearer [REDACTED]")
        return result
    }

    private fun shareQa(path: String) {
        val file = File(path).canonicalFile
        val root = exportRoot().canonicalFile
        require(file.isFile && file.extension == "zip" && file.path.startsWith(root.path + File.separator)) {
            "Only generated QA ZIPs can be shared"
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.qa-files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/zip"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "ORBIT Visual Lab QA")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, "Share local ORBIT QA ZIP"))
    }

    private fun packageInfo(field: String): Any {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return when (field) {
            "versionName" -> info.versionName ?: "unknown"
            "versionCode" -> info.longVersionCode
            else -> "unknown"
        }
    }

    private fun writeJson(file: File, value: JSONObject): File = file.apply {
        writeText(value.toString(2))
    }

    private fun writeRawJson(file: File, value: String): File = file.apply {
        // Validate data received from Dart before placing it in the evidence ZIP.
        writeText(JSONObject(value).toString(2))
    }

    private fun captureRoot(): File = File(activity.filesDir, "qa_captures").apply { mkdirs() }

    private fun exportRoot(): File {
        val base = activity.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS) ?: activity.filesDir
        return File(base, "ORBIT_QA").apply { mkdirs() }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun safeName(value: String): String = value.replace(Regex("[^A-Za-z0-9._-]"), "_")

    private fun timestamp(): String = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.format(Date())

    companion object {
        private const val TAG = "ORBIT_QA"
    }
}
