package com.shianman.custom_map_marker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var tileRenderer: TileRenderer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tileRenderer = TileRenderer(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        tileRenderer?.dispose()
        tileRenderer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
