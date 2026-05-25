package com.depthmap24.imageviewer

import android.app.ActivityManager
import android.app.Application
import android.app.ApplicationExitInfo
import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class Application : Application() {

    override fun onCreate() {
        // ── Step 1: read the OS-recorded reason for the PREVIOUS crash ────────
        // ActivityManager.getHistoricalProcessExitReasons() is available on API 30+
        // and is populated by the SYSTEM — it captures native crashes, ANRs, and
        // Java exceptions even when our own handler never ran.
        // We do this BEFORE installing our own handler and before super.onCreate()
        // so that even if onCreate() crashes, previous data is persisted first.
        readAndWriteExitHistory()

        // ── Step 2: install crash handler for THIS session ────────────────────
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val report = buildString {
                    append("=== CRASH at ${timestamp()} ===\n")
                    append("Thread: ${thread.name}\n")
                    append("Android: ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})\n")
                    append("Device: ${Build.MANUFACTURER} ${Build.MODEL}\n\n")
                    append(throwable.stackTraceToString())
                }
                writeToDownloads("imageviewer_crash.txt", report)
                for (dir in crashDirs()) {
                    try { dir.mkdirs(); File(dir, "imageviewer_crash.txt").writeText(report); break }
                    catch (_: Exception) {}
                }
            } catch (_: Exception) {}
            defaultHandler?.uncaughtException(thread, throwable)
        }

        super.onCreate()
    }

    // ── Reads up to 5 historical exit reasons and writes them to Downloads ────
    private fun readAndWriteExitHistory() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return   // API 30+
        try {
            val am = getSystemService(ActivityManager::class.java) ?: return
            val reasons: List<ApplicationExitInfo> =
                am.getHistoricalProcessExitReasons(packageName, 0, 5)
            if (reasons.isEmpty()) return

            val sb = StringBuilder()
            sb.append("=== ImageViewer exit history (${timestamp()}) ===\n")
            sb.append("App version: ${packageManager.getPackageInfo(packageName, 0).versionName}\n")
            sb.append("Android: ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})\n")
            sb.append("Device: ${Build.MANUFACTURER} ${Build.MODEL}\n\n")

            for ((i, info) in reasons.withIndex()) {
                sb.append("--- Exit #${i + 1} at ${Date(info.timestamp)} ---\n")
                sb.append("Reason : ${exitReasonName(info.reason)} (${info.reason})\n")
                sb.append("Description: ${info.description}\n")
                sb.append("Status : ${info.status}\n")
                // traceInputStream is non-null for CRASH, CRASH_NATIVE, and ANR
                try {
                    info.traceInputStream?.bufferedReader()?.use { r ->
                        val trace = r.readText()
                        if (trace.isNotBlank()) {
                            sb.append("Trace:\n$trace\n")
                        }
                    }
                } catch (_: Exception) {}
                sb.append("\n")
            }

            writeToDownloads("imageviewer_exit_history.txt", sb.toString())
        } catch (_: Exception) {}
    }

    // ── Writes text to public Downloads via MediaStore (no special permission) ─
    private fun writeToDownloads(filename: String, text: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // API 29+: use MediaStore — visible in any file manager / Downloads app
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, "Download/imageviewer/")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                ) ?: return
                contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            } else {
                // API 28-: write directly to Downloads directory
                val dir = File(
                    android.os.Environment.getExternalStoragePublicDirectory(
                        android.os.Environment.DIRECTORY_DOWNLOADS
                    ), "imageviewer"
                )
                dir.mkdirs()
                File(dir, filename).writeText(text)
            }
        } catch (_: Exception) {
            // Fall back to internal storage
            try { File(filesDir, filename).writeText(text) } catch (_: Exception) {}
        }
    }

    private fun timestamp() =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())

    private fun exitReasonName(reason: Int) = when (reason) {
        ApplicationExitInfo.REASON_ANR              -> "ANR"
        ApplicationExitInfo.REASON_CRASH            -> "JAVA_CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE     -> "NATIVE_CRASH"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED  -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE"
        ApplicationExitInfo.REASON_EXIT_SELF        -> "EXIT_SELF"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INIT_FAILURE"
        ApplicationExitInfo.REASON_LOW_MEMORY       -> "LOW_MEMORY"
        ApplicationExitInfo.REASON_OTHER            -> "OTHER"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_SIGNALED         -> "SIGNALED"
        ApplicationExitInfo.REASON_USER_REQUESTED   -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED     -> "USER_STOPPED"
        ApplicationExitInfo.REASON_PACKAGE_UPDATED  -> "PACKAGE_UPDATED"
        else                                        -> "UNKNOWN($reason)"
    }

    private fun crashDirs(): List<File> = buildList {
        val ext = getExternalFilesDir(null)
        if (ext != null) add(ext)
        add(filesDir)
    }
}
