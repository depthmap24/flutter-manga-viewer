package com.zen24.imageviewer

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ImageViewerApplication : Application() {

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        installCrashHandler(base)
        markBoot(base, "Application.attachBaseContext")
    }

    override fun onCreate() {
        super.onCreate()
        markBoot(this, "Application.onCreate")

        // Pre-warm the Flutter engine here, before any Activity starts.
        // No Activity visible → no input-dispatching ANR watchdog (5 s limit).
        // If FlutterEngine() hangs for 5-6 s it just delays startup; it does NOT
        // cause the crash/SIGKILL that was happening inside provideFlutterEngine().
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            markBoot(this, "FlutterLoader.startInit")
            loader.startInitialization(this)
            markBoot(this, "FlutterLoader.ensureComplete")
            loader.ensureInitializationComplete(this, null)
            markBoot(this, "FlutterLoader.ensureComplete done")

            markBoot(this, "FlutterEngine() start — pre-warming before Activity")
            val engine = FlutterEngine(this, null as Array<String>?, false)
            markBoot(this, "FlutterEngine() done — caching")
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            markBoot(this, "engine cached OK")
        } catch (t: Throwable) {
            persistCrash(this, "Application.onCreate FlutterEngine", t)
            markBoot(this, "FlutterEngine FAILED: ${t.javaClass.simpleName}: ${t.message}")
        }
    }

    private fun installCrashHandler(ctx: Context) {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                persistCrash(ctx, "Uncaught thread=${thread.name}", throwable)
            } catch (_: Throwable) {}
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
            } catch (_: Throwable) {}
        }
    }

    companion object {
        const val ENGINE_ID = "main_engine"
        private const val TAG = "ImageViewerCrash"
    }
}
