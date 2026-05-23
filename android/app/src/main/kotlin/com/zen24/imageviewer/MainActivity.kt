package com.zen24.imageviewer

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install the native uncaught-exception handler FIRST so anything that
        // blows up in plugin registration, JNI, or the Flutter engine bring-up
        // gets persisted before the process dies.
        installNativeCrashHandler()
        appendBootMark("MainActivity.onCreate enter")

        // Watchdog: fires if we're still alive 20 s later (helps distinguish
        // a hang from an instant native crash).
        mainHandler.postDelayed({
            appendBootMark("watchdog: still alive +20s after onCreate start")
        }, 20_000L)

        try {
            super.onCreate(savedInstanceState)
            mainHandler.removeCallbacksAndMessages(null)
            appendBootMark("MainActivity.onCreate exit")
        } catch (t: Throwable) {
            persistCrash("MainActivity.onCreate", t)
            throw t
        }
    }

    // Create the FlutterEngine ourselves so we can place marks around each
    // sub-step.  Returning non-null here prevents FlutterActivity from calling
    // `new FlutterEngine()` internally (which is where the crash was happening).
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        appendBootMark("provideFlutterEngine start")
        return try {
            val loader = FlutterInjector.instance().flutterLoader()

            // startInitialization is idempotent; FlutterApplication may have
            // already called it, but calling again is safe.
            appendBootMark("FlutterLoader.startInit start")
            loader.startInitialization(context.applicationContext)
            appendBootMark("FlutterLoader.startInit done")

            // ensureInitializationComplete blocks until native init finishes,
            // including System.loadLibrary("flutter") → libflutter.so JNI_OnLoad.
            // If a SIGSEGV fires here the last mark in the log will be "start".
            appendBootMark("FlutterLoader.ensureComplete start")
            loader.ensureInitializationComplete(context.applicationContext, null)
            appendBootMark("FlutterLoader.ensureComplete done")

            // FlutterEngine() wires up the Dart VM and FlutterJNI.
            appendBootMark("FlutterEngine() start")
            val engine = FlutterEngine(context)
            appendBootMark("FlutterEngine() done")
            engine
        } catch (t: Throwable) {
            persistCrash("provideFlutterEngine", t)
            appendBootMark("provideFlutterEngine FAILED: ${t.javaClass.simpleName}")
            throw t
        }
    }

    // Register each plugin individually so a crash in one pinpoints the culprit.
    // (Replaces the default GeneratedPluginRegistrant.registerWith() batch call.)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        appendBootMark("configureFlutterEngine start")
        registerPlugin(flutterEngine, "app_links")       { com.llfbandit.app_links.AppLinksPlugin() }
        registerPlugin(flutterEngine, "jni")             { com.github.dart_lang.jni.JniPlugin() }
        registerPlugin(flutterEngine, "jni_flutter")     { com.github.dart_lang.jni_flutter.JniFlutterPlugin() }
        registerPlugin(flutterEngine, "open_filex")      { com.crazecoder.openfile.OpenFilePlugin() }
        registerPlugin(flutterEngine, "package_info_plus") { dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin() }
        registerPlugin(flutterEngine, "permission_handler") { com.baseflow.permissionhandler.PermissionHandlerPlugin() }
        registerPlugin(flutterEngine, "photo_manager")   { com.fluttercandies.photo_manager.PhotoManagerPlugin() }
        registerPlugin(flutterEngine, "share_plus")      { dev.fluttercommunity.plus.share.SharePlusPlugin() }
        registerPlugin(flutterEngine, "url_launcher")    { io.flutter.plugins.urllauncher.UrlLauncherPlugin() }
        appendBootMark("configureFlutterEngine done")
    }

    private fun registerPlugin(
        engine: FlutterEngine,
        name: String,
        factory: () -> FlutterPlugin
    ) {
        appendBootMark("plugin $name: registering")
        try {
            engine.plugins.add(factory())
            appendBootMark("plugin $name: ok")
        } catch (t: Throwable) {
            persistCrash("plugin $name registration", t)
            appendBootMark("plugin $name: FAILED ${t.javaClass.simpleName}")
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
