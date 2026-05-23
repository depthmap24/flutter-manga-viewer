package com.zen24.imageviewer

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.loader.FlutterLoader
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Custom Application that installs an uncaught-exception handler as early as
 * possible — even before MainActivity.onCreate — so we capture failures in:
 *   * Application init (ContentProviders, other Applications)
 *   * Plugin registration
 *   * Flutter engine native bring-up
 *
 * The handler writes to the app's external files dir, which is browsable by
 * any file manager at /sdcard/Android/data/com.zen24.imageviewer/files/
 * without any runtime permission.
 *
 * We extend FlutterApplication to keep multi-dex behavior the Flutter Gradle
 * plugin assumes via ${applicationName} in the manifest.
 */
// Extend Application (not the deprecated FlutterApplication).
// FlutterApplication.onCreate() calls FlutterLoader.startInitialization() which
// spawns background threads for native init — if those threads crash they kill
// the process before MainActivity.onCreate() even reaches the engine setup.
// Extending plain Application avoids that async path; FlutterActivity calls
// ensureInitializationComplete() synchronously on the main thread instead.
class ImageViewerApplication : Application() {

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        installCrashHandler(base)
        markBoot(base, "Application.attachBaseContext")
    }

    override fun onCreate() {
        super.onCreate()
        markBoot(this, "Application.onCreate")
    }

    private fun installCrashHandler(ctx: Context) {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                persistCrash(ctx, "Uncaught thread=${thread.name}", throwable)
            } catch (_: Throwable) {/* swallow */}
            previous?.uncaughtException(thread, throwable)
        }
    }

    private fun persistCrash(ctx: Context, phase: String, throwable: Throwable) {
        val sw = StringWriter()
        throwable.printStackTrace(PrintWriter(sw))
        val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val body = buildString {
            appendLine("[$ts] $phase")
            appendLine("device: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("android: ${Build.VERSION.RELEASE} (sdk ${Build.VERSION.SDK_INT})")
            appendLine("abis: ${Build.SUPPORTED_ABIS.joinToString(",")}")
            appendLine("---")
            append(sw.toString())
        }
        Log.e(TAG, body)
        writeFile(ctx, "native_crash.log", body, append = false)
    }

    private fun markBoot(ctx: Context, msg: String) {
        val ts = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val line = "[$ts] $msg\n"
        Log.i(TAG, line.trim())
        writeFile(ctx, "boot_trace.log", line, append = true)
    }

    private fun writeFile(ctx: Context, name: String, body: String, append: Boolean) {
        val dirs = listOfNotNull(ctx.filesDir, ctx.getExternalFilesDir(null))
        for (d in dirs) {
            try {
                if (!d.exists()) d.mkdirs()
                val f = File(d, name)
                if (append) f.appendText(body) else f.writeText(body)
            } catch (_: Throwable) {/* ignore */}
        }
    }

    companion object {
        private const val TAG = "ImageViewerCrash"
    }
}
