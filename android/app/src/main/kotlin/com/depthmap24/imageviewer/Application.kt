package com.depthmap24.imageviewer

import android.app.Application
import java.io.File

class Application : Application() {

    override fun onCreate() {
        super.onCreate()

        // Write uncaught exceptions to crash.txt before the default handler kills the process.
        // Dart reads this file on next launch and shows it in the LogScreen.
        val crashFile = File(filesDir, "crash.txt")
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                crashFile.writeText(
                    "Thread: ${thread.name}\n${throwable.stackTraceToString()}"
                )
            } catch (_: Exception) {}
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
