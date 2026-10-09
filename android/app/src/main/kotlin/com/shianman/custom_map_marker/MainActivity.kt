package com.shianman.custom_map_marker

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var tileRenderer: TileRenderer? = null
    private var incomingFiles: IncomingFiles? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A restored activity, or one relaunched from recents, still carries
        // the intent it was first opened with; importing it again would
        // duplicate the map.
        val fromHistory =
            intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (savedInstanceState == null && !fromHistory) consume(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        consume(intent)
    }

    private fun consume(intent: Intent) {
        if (incomingFiles?.handle(intent) == true) {
            // Forget the file so a later recreation doesn't import it again.
            setIntent(Intent(Intent.ACTION_MAIN))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tileRenderer = TileRenderer(flutterEngine.dartExecutor.binaryMessenger)
        incomingFiles = IncomingFiles(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        tileRenderer?.dispose()
        tileRenderer = null
        incomingFiles?.dispose()
        incomingFiles = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
