package com.shianman.custom_map_marker

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Receives map files opened from other apps ("Open with…" in Files, Gmail,
 * Drive) or shared to this app. Content URIs are only readable while the
 * grant lasts, so each file is copied into the cache right away and Dart is
 * handed a plain path.
 *
 * Protocol (all on the main thread, so there are no races): copied files wait
 * in [pending]; Dart pulls them with `takePending` when it starts listening and
 * whenever it's told `filesAvailable`.
 */
class IncomingFiles(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "custom_map_marker/incoming")
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<Map<String, String>>()
    private var listening = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    listening = true
                    result.success(pending.toList())
                    pending.clear()
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Starts copying the file [intent] carries, if any. Returns whether it had one. */
    fun handle(intent: Intent?): Boolean {
        val uri = uriOf(intent) ?: return false
        executor.execute {
            val entry = try {
                mapOf("path" to copyToCache(uri))
            } catch (e: Exception) {
                mapOf("error" to (e.message ?: e.javaClass.simpleName))
            }
            mainHandler.post {
                pending.add(entry)
                if (listening) channel.invokeMethod("filesAvailable", null)
            }
        }
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private fun uriOf(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND ->
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        else -> null
    }

    private fun copyToCache(uri: Uri): String {
        val dir = File(context.cacheDir, "incoming").apply { mkdirs() }
        val file = File(dir, "${System.currentTimeMillis()}.cmm")
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Cannot open $uri")
        try {
            input.use { src -> file.outputStream().use { dst -> src.copyTo(dst) } }
        } catch (e: Exception) {
            file.delete()
            throw e
        }
        return file.absolutePath
    }
}
