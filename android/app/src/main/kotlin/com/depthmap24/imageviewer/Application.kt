package com.depthmap24.imageviewer

import android.app.Application
import android.os.Environment
import java.io.File

class Application : Application() {

    override fun onCreate() {
        super.onCreate()

        // Write uncaught exceptions to a file readable by the user.
        // Priority: Downloads folder (visible in any file manager) →
        //           app external files dir (visible via USB/MTP) →
        //           internal files dir (last resort).
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val report = "Thread: ${thread.name}\n${throwable.stackTraceToString()}"
                val target = resolveLogDir()
                target.mkdirs()
                File(target, "imageviewer_crash.txt").writeText(report)
            } catch (_: Exception) {}
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    /** Returns the most user-accessible directory that is writable right now. */
    private fun resolveLogDir(): File {
        // Downloads — accessible in every file manager, no permission needed on Android ≤ 10
        // with requestLegacyExternalStorage="true", and on 11+ if MANAGE_EXTERNAL_STORAGE granted.
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val dlTarget = File(downloads, "imageviewer")
        if (dlTarget.exists() || dlTarget.mkdirs()) return dlTarget

        // App-specific external dir — no permission needed on any Android version,
        // reachable via USB / MTP even on Android 11+.
        val ext = getExternalFilesDir(null)
        if (ext != null) return ext

        // Internal files dir — always available, not visible to file managers.
        return filesDir
    }
}
