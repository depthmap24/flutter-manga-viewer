package com.zen24.imageviewer

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
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

        // Probe whether FlutterEngine() can succeed on a background thread.
        // The main-thread path blocks the UI thread; Android's ANR watchdog sends
        // SIGKILL after ~5 s of blocking.  If we run the same constructor on a
        // bg thread (no watchdog), we can distinguish:
        //   "bg-probe: done" in log → engine CAN complete, just takes > 5 s on
        //                             the main thread → ANR, not a crash
        //   "bg-probe: start" with no "done" before process death → real crash
        val appCtx = applicationContext
        Thread {
            try {
                bgMark("bg-probe: FlutterLoader.startInit")
                FlutterInjector.instance().flutterLoader().startInitialization(appCtx)
                bgMark("bg-probe: FlutterLoader.ensureComplete")
                FlutterInjector.instance().flutterLoader().ensureInitializationComplete(appCtx, null)
                bgMark("bg-probe: FlutterEngine() start")
                val engine = FlutterEngine(appCtx, null as Array<String>?, false)
                bgMark("bg-probe: FlutterEngine() done — engine CAN be created on bg thread!")
                engine.destroy()  // We don't need it, just testing
                bgMark("bg-probe: engine destroyed")
            } catch (t: Throwable) {
                bgMark("bg-probe: FAILED ${t.javaClass.simpleName}: ${t.message}")
            }
        }.apply {
            name = "flutter-engine-probe"
            isDaemon = true  // Don't keep process alive just for this probe
        }.start()
    }

    private fun bgMark(msg: String) {
        val ts = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val line = "[$ts] $msg\n"
        Log.i(TAG, line.trim())
        // Use applicationContext so filesDir is available
        val dirs = listOfNotNull(filesDir, getExternalFilesDir(null))
        for (d in dirs) {
            try {
                if (!d.exists()) d.mkdirs()
                File(d, "boot_trace.log").appendText(line)
            } catch (_: Throwable) {}
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
        private const val TAG = "ImageViewerCrash"
    }
}
