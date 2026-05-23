package com.zen24.imageviewer

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
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

    // Create the engine with no auto-plugins so we can mark each sub-step.
    // jni + jni_flutter are omitted: they load libdartjni.so (compiled on our
    // ARM64 host via box64/NDK) which may have a native crash on device.
    // photo_manager still works via its Java MethodChannel path without jni.
    @Suppress("UNCHECKED_CAST")
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        appendBootMark("provideFlutterEngine start")
        return try {
            val loader = FlutterInjector.instance().flutterLoader()
            appendBootMark("FlutterLoader.startInit start")
            loader.startInitialization(context.applicationContext)
            appendBootMark("FlutterLoader.startInit done")

            appendBootMark("FlutterLoader.ensureComplete start")
            loader.ensureInitializationComplete(context.applicationContext, null)
            appendBootMark("FlutterLoader.ensureComplete done")

            appendBootMark("FlutterEngine(no-auto-plugins) start")
            val engine = FlutterEngine(context, null as Array<String>?, false)
            appendBootMark("FlutterEngine(no-auto-plugins) done")

            // jni + jni_flutter omitted — they load libdartjni.so which crashes.
            registerPlugin(engine, "app_links")         { com.llfbandit.app_links.AppLinksPlugin() }
            registerPlugin(engine, "open_filex")        { com.crazecoder.openfile.OpenFilePlugin() }
            registerPlugin(engine, "package_info_plus") { dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin() }
            registerPlugin(engine, "permission_handler") { com.baseflow.permissionhandler.PermissionHandlerPlugin() }
            registerPlugin(engine, "photo_manager")     { com.fluttercandies.photo_manager.PhotoManagerPlugin() }
            registerPlugin(engine, "share_plus")        { dev.fluttercommunity.plus.share.SharePlusPlugin() }
            registerPlugin(engine, "url_launcher")      { io.flutter.plugins.urllauncher.UrlLauncherPlugin() }
            appendBootMark("all plugins registered")
            engine
        } catch (t: Throwable) {
            persistCrash("provideFlutterEngine", t)
            appendBootMark("provideFlutterEngine FAILED: ${t.javaClass.simpleName}")
            throw t
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        appendBootMark("configureFlutterEngine: plugins already registered, skipping")
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
