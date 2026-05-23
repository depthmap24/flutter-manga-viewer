package com.zen24.imageviewer

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install the native uncaught-exception handler FIRST so anything that
        // blows up in plugin registration, JNI, or the Flutter engine bring-up
        // gets persisted before the process dies.
        installNativeCrashHandler()
        appendBootMark("MainActivity.onCreate enter")
        try {
            super.onCreate(savedInstanceState)
            appendBootMark("MainActivity.onCreate exit")
        } catch (t: Throwable) {
            persistCrash("MainActivity.onCreate", t)
            throw t
        }
    }

    override fun onNewIntent(intent: Intent) {
        appendBootMark("onNewIntent action=${intent.action}")
        super.onNewIntent(intent)
    }

    private fun installNativeCrashHandler() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                persistCrash("UncaughtExceptionHandler thread=${thread.name}", throwable)
            } catch (_: Throwable) {
                // We're already in a fatal path — swallow any logging error.
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    private fun persistCrash(phase: String, throwable: Throwable) {
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
        writeToFiles("native_crash.log", body)
    }

    private fun appendBootMark(message: String) {
        val ts = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(Date())
        val line = "[$ts] $message\n"
        Log.i(TAG, line.trim())
        writeToFiles("boot_trace.log", line, append = true)
    }

    private fun writeToFiles(name: String, body: String, append: Boolean = false) {
        // Write to BOTH internal and external app-files dirs. External is
        // user-accessible at /sdcard/Android/data/<package>/files/ without
        // any runtime permission, so users can fetch the log with any file
        // manager. Internal is the bulletproof fallback.
        val targets = listOfNotNull(filesDir, getExternalFilesDir(null))
        for (target in targets) {
            try {
                if (!target.exists()) target.mkdirs()
                val file = File(target, name)
                if (append) file.appendText(body) else file.writeText(body)
            } catch (_: Throwable) {
                // Ignore — logging itself must never crash.
            }
        }
    }

    companion object {
        private const val TAG = "ImageViewerCrash"
    }
}
