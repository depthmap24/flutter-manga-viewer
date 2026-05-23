package com.zen24.imageviewer

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
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

    // Return the engine pre-warmed in Application.onCreate().
    // All the slow GPU/JNI init happened there (before any Activity was visible),
    // so this call should be near-instant and never ANR.
    @Suppress("UNCHECKED_CAST")
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        appendBootMark("provideFlutterEngine: fetching pre-warmed engine")
        val cached = FlutterEngineCache.getInstance().get(ImageViewerApplication.ENGINE_ID)
        return if (cached != null) {
            appendBootMark("provideFlutterEngine: cache hit — registering plugins")
            registerPlugin(cached, "app_links")         { com.llfbandit.app_links.AppLinksPlugin() }
            registerPlugin(cached, "open_filex")        { com.crazecoder.openfile.OpenFilePlugin() }
            registerPlugin(cached, "package_info_plus") { dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin() }
            registerPlugin(cached, "permission_handler") { com.baseflow.permissionhandler.PermissionHandlerPlugin() }
            registerPlugin(cached, "photo_manager")     { com.fluttercandies.photo_manager.PhotoManagerPlugin() }
            registerPlugin(cached, "share_plus")        { dev.fluttercommunity.plus.share.SharePlusPlugin() }
            registerPlugin(cached, "url_launcher")      { io.flutter.plugins.urllauncher.UrlLauncherPlugin() }
            appendBootMark("provideFlutterEngine: plugins registered, returning engine")
            cached
        } else {
            // Application.onCreate() failed to pre-warm — fall back to on-demand creation.
            // This will likely ANR on S25+, but at least we'll know the cache missed.
            appendBootMark("provideFlutterEngine: cache MISS — falling back to on-demand")
            null  // Let FlutterActivity create one via the default path
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Plugins already registered in provideFlutterEngine; skip auto-registration.
        appendBootMark("configureFlutterEngine: plugins already set, skipping super")
    }

    private fun registerPlugin(engine: FlutterEngine, name: String, factory: () -> FlutterPlugin) {
        appendBootMark("plugin $name: registering")
        try {
            engine.plugins.add(factory())
            appendBootMark("plugin $name: ok")
        } catch (t: Throwable) {
            persistCrash("plugin $name", t)
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
            } catch (_: Throwable) {}
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
        val targets = listOfNotNull(filesDir, getExternalFilesDir(null))
        for (target in targets) {
            try {
                if (!target.exists()) target.mkdirs()
                val file = File(target, name)
                if (append) file.appendText(body) else file.writeText(body)
            } catch (_: Throwable) {}
        }
    }

    companion object {
        private const val TAG = "ImageViewerCrash"
    }
}
