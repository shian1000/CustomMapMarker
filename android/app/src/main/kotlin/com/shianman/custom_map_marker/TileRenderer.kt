package com.shianman.custom_map_marker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.ceil
import kotlin.math.min

/**
 * Renders single tiles of a large map image on demand, without decoding the
 * whole image: [BitmapRegionDecoder] decodes only the tile's region, and
 * `inSampleSize` downsamples it for lower zoom levels.
 *
 * The tile layout must match `TilePyramid` in lib/core/tile_pyramid.dart:
 * level `maxZoom` is full resolution, each level below halves it, tiles are
 * TILE_SIZE squares, and edge tiles are padded with transparency.
 */
class TileRenderer(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler(this)
    }
    private val executor = Executors.newFixedThreadPool(THREADS)
    private val mainHandler = Handler(Looper.getMainLooper())

    // Opening a decoder parses the file header; reuse it across tiles.
    private val decoders = object : LruCache<String, BitmapRegionDecoder>(2) {
        override fun entryRemoved(
            evicted: Boolean,
            key: String,
            oldValue: BitmapRegionDecoder,
            newValue: BitmapRegionDecoder?,
        ) = oldValue.recycle()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "renderTile") return result.notImplemented()
        val imagePath = call.argument<String>("imagePath")!!
        val outPath = call.argument<String>("outPath")!!
        val zoom = call.argument<Int>("zoom")!!
        val x = call.argument<Int>("x")!!
        val y = call.argument<Int>("y")!!
        val maxZoom = call.argument<Int>("maxZoom")!!

        executor.execute {
            try {
                renderTile(imagePath, outPath, zoom, x, y, maxZoom)
                mainHandler.post { result.success(null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("RENDER_FAILED", e.toString(), null) }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
        synchronized(decoders) { decoders.evictAll() }
    }

    private fun decoderFor(path: String): BitmapRegionDecoder = synchronized(decoders) {
        decoders.get(path) ?: newDecoder(path).also { decoders.put(path, it) }
    }

    @Suppress("DEPRECATION")
    private fun newDecoder(path: String): BitmapRegionDecoder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            BitmapRegionDecoder.newInstance(path)
        } else {
            BitmapRegionDecoder.newInstance(path, false)
        } ?: throw IllegalArgumentException("Cannot decode $path")

    private fun renderTile(
        imagePath: String,
        outPath: String,
        zoom: Int,
        x: Int,
        y: Int,
        maxZoom: Int,
    ) {
        val decoder = decoderFor(imagePath)
        val sample = 1 shl (maxZoom - zoom)
        val span = TILE_SIZE * sample
        val left = x * span
        val top = y * span
        val right = min(left + span, decoder.width)
        val bottom = min(top + span, decoder.height)
        require(left < right && top < bottom) { "Tile $zoom/$x/$y is outside the image" }

        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        // The decoder serializes calls internally; this just makes it explicit.
        val region = synchronized(decoder) {
            decoder.decodeRegion(Rect(left, top, right, bottom), options)
        } ?: throw IllegalStateException("Failed to decode tile $zoom/$x/$y")

        // Size on this level, rounded up like TilePyramid.levelWidth. The
        // decoder may round differently, so draw scaled to exactly this.
        val width = ceil((right - left) / sample.toDouble()).toInt()
        val height = ceil((bottom - top) / sample.toDouble()).toInt()
        val isFull = width == TILE_SIZE && height == TILE_SIZE
        val opaque = isFull && !region.hasAlpha()

        val tile = Bitmap.createBitmap(TILE_SIZE, TILE_SIZE, Bitmap.Config.ARGB_8888)
        Canvas(tile).drawBitmap(
            region,
            null,
            Rect(0, 0, width, height),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        region.recycle()

        // Write to a temp file and rename, so a half-written tile is never read.
        val out = File(outPath)
        out.parentFile?.mkdirs()
        val tmp = File(out.parentFile, "${out.name}.tmp-${Thread.currentThread().id}")
        FileOutputStream(tmp).use { stream ->
            if (opaque) {
                tile.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)
            } else {
                tile.compress(Bitmap.CompressFormat.PNG, 100, stream)
            }
        }
        tile.recycle()
        if (!tmp.renameTo(out)) {
            tmp.delete()
            throw IllegalStateException("Cannot write $outPath")
        }
    }

    private companion object {
        const val CHANNEL = "custom_map_marker/tiles"
        const val TILE_SIZE = 256
        const val JPEG_QUALITY = 88
        const val THREADS = 3
    }
}
