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

    // Create the engine ourselves (no auto-plugins) so we can mark each step.
    // Impeller is already disabled via manifest EnableImpeller=false; this lets
    // us confirm whether the engine init succeeds with Impeller off.
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

            // automaticallyRegisterPlugins=false so JniPlugin is NOT loaded here.
            appendBootMark("FlutterEngine(no-auto-plugins) start")
            val engine = FlutterEngine(context, null as Array<String>?, false)
            appendBootMark("FlutterEngine(no-auto-plugins) done")

            // Register plugins one by one.
            registerPlugin(engine, "app_links")         { com.llfbandit.app_links.AppLinksPlugin() }
            registerPlugin(engine, "jni")               { com.github.dart_lang.jni.JniPlugin() }
            registerPlugin(engine, "jni_flutter")       { com.github.dart_lang.jni_flutter.JniFlutterPlugin() }
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
