package com.depthmap24.imageviewer

import android.app.Application
import java.io.File

class Application : Application() {

    override fun onCreate() {
        // Install crash handler BEFORE super.onCreate() so plugin initialisation
        // failures are also captured.
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val report = "Thread: ${thread.name}\n${throwable.stackTraceToString()}"
                // Write to every candidate in order; stop at the first success.
                for (dir in crashDirs()) {
                    try {
                        dir.mkdirs()
                        File(dir, "imageviewer_crash.txt").writeText(report)
                        break
                    } catch (_: Exception) {}
                }
            } catch (_: Exception) {}
            defaultHandler?.uncaughtException(thread, throwable)
        }

        super.onCreate()
    }

    /** Candidate directories in preference order. The crash handler tries each in turn. */
    private fun crashDirs(): List<File> = buildList {
        // App external-files dir — no permission needed on any Android version,
        // reachable via USB/MTP at /sdcard/Android/data/<pkg>/files/
        val ext = getExternalFilesDir(null)
        if (ext != null) add(ext)

        // Internal files dir — always available, not visible to file managers
        add(filesDir)
    }
}
