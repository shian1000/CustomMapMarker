package com.shianman.custom_map_marker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Canvas
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
import java.util.concurrent.ExecutorCompletionService
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
        when (call.method) {
            "renderTile" -> onRenderTile(call, result)
            "generateAllTiles" -> onGenerateAllTiles(call, result)
            else -> result.notImplemented()
        }
    }

    private fun onGenerateAllTiles(call: MethodCall, result: MethodChannel.Result) {
        val imagePath = call.argument<String>("imagePath")!!
        val tilesDir = call.argument<String>("tilesDir")!!
        val maxZoom = call.argument<Int>("maxZoom")!!
        val taskId = call.argument<Int>("taskId")!!

        executor.execute {
            try {
                generateAllTiles(imagePath, tilesDir, maxZoom) { progress ->
                    mainHandler.post {
                        channel.invokeMethod(
                            "progress",
                            mapOf("taskId" to taskId, "value" to progress),
                        )
                    }
                }
                mainHandler.post { result.success(null) }
            } catch (e: TooLargeException) {
                mainHandler.post { result.error("TOO_LARGE", e.message, null) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("GENERATE_FAILED", e.toString(), null) }
            }
        }
    }

    private fun onRenderTile(call: MethodCall, result: MethodChannel.Result) {
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

    /**
     * Decodes the whole image once and writes every tile of the pyramid.
     *
     * Needed for PNG/WebP: unlike JPEG, they can't be decoded from the middle,
     * so [BitmapRegionDecoder] re-reads the image from the top for every tile,
     * which made on-demand tiles of a 40 MP PNG take tens of seconds.
     *
     * Compressing the tiles takes far longer than decoding, so they're
     * compressed on several threads; at most [IN_FLIGHT] cropped tiles wait in
     * memory at a time.
     */
    private fun generateAllTiles(
        imagePath: String,
        tilesDir: String,
        maxZoom: Int,
        report: (Double) -> Unit,
    ) {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(imagePath, bounds)
        val width = bounds.outWidth
        val height = bounds.outHeight
        require(width > 0 && height > 0) { "Cannot read $imagePath" }

        // The full-resolution bitmap plus the half-size level made from it.
        val needed = width.toLong() * height * 4 * 5 / 4
        val runtime = Runtime.getRuntime()
        val javaFree = runtime.maxMemory() - (runtime.totalMemory() - runtime.freeMemory())
        // Bitmap pixels live in the native heap since Android 8, outside the
        // Java heap limit; before that they count against it.
        val budget = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            availableSystemMemory() / 2
        } else {
            javaFree
        }
        if (needed > budget) throw TooLargeException("Needs $needed bytes, budget $budget")

        var level = BitmapFactory.decodeFile(
            imagePath,
            BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 },
        ) ?: throw IllegalStateException("Cannot decode $imagePath")

        val total = (0..maxZoom).sumOf { z ->
            val lw = ceilDiv(width, 1 shl (maxZoom - z))
            val lh = ceilDiv(height, 1 shl (maxZoom - z))
            ceilDiv(lw, TILE_SIZE) * ceilDiv(lh, TILE_SIZE)
        }
        var done = 0
        var lastReported = -1
        val pool = Executors.newFixedThreadPool(compressThreads())
        val written = ExecutorCompletionService<Unit>(pool)
        var inFlight = 0

        // Waits for one submitted tile; rethrows its failure.
        fun awaitOne() {
            written.take().get()
            inFlight--
            done++
            val percent = done * 100 / total
            if (percent != lastReported) {
                lastReported = percent
                report(done.toDouble() / total)
            }
        }

        try {
            for (z in maxZoom downTo 0) {
                if (z < maxZoom) {
                    // Same rounding as TilePyramid.levelWidth/levelHeight.
                    val next = Bitmap.createScaledBitmap(
                        level,
                        ceilDiv(level.width, 2),
                        ceilDiv(level.height, 2),
                        true,
                    )
                    if (next !== level) level.recycle()
                    level = next
                }
                for (x in 0 until ceilDiv(level.width, TILE_SIZE)) {
                    for (y in 0 until ceilDiv(level.height, TILE_SIZE)) {
                        val left = x * TILE_SIZE
                        val top = y * TILE_SIZE
                        val cropWidth = min(TILE_SIZE, level.width - left)
                        val cropHeight = min(TILE_SIZE, level.height - top)
                        // createBitmap returns the source itself for a crop
                        // of all of it; the tile job recycles its crop.
                        val crop = if (cropWidth == level.width && cropHeight == level.height) {
                            level.copy(level.config ?: Bitmap.Config.ARGB_8888, false)
                        } else {
                            Bitmap.createBitmap(level, left, top, cropWidth, cropHeight)
                        }
                        if (inFlight == IN_FLIGHT) awaitOne()
                        val out = File(tilesDir, "$z/$x/$y")
                        written.submit {
                            writeTile(crop, out)
                            crop.recycle()
                        }
                        inFlight++
                    }
                }
            }
            while (inFlight > 0) awaitOne()
        } finally {
            pool.shutdownNow()
            level.recycle()
        }
    }

    private fun availableSystemMemory(): Long {
        // /proc/meminfo needs no Context; MemAvailable is in kB.
        return File("/proc/meminfo").useLines { lines ->
            lines.firstOrNull { it.startsWith("MemAvailable:") }
                ?.split(Regex("\\s+"))?.getOrNull(1)?.toLongOrNull()
        }?.times(1024) ?: Long.MAX_VALUE
    }

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

        val scaled = if (region.width == width && region.height == height) {
            region
        } else {
            Bitmap.createScaledBitmap(region, width, height, true).also { region.recycle() }
        }
        writeTile(scaled, File(outPath))
        scaled.recycle()
    }

    /**
     * Writes [content] (at most TILE_SIZE square) as a tile: JPEG when it fills
     * the whole tile and has no transparent pixels, otherwise PNG padded with
     * transparency. Writes to a temp file and renames it, so a half-written
     * tile is never read.
     */
    private fun writeTile(content: Bitmap, out: File) {
        val isFull = content.width == TILE_SIZE && content.height == TILE_SIZE
        // PNG compression is many times slower than JPEG, and plenty of PNG
        // maps carry an alpha channel without using it.
        val asJpeg = isFull && isOpaque(content)
        val tile = if (isFull) {
            content
        } else {
            Bitmap.createBitmap(TILE_SIZE, TILE_SIZE, Bitmap.Config.ARGB_8888).also {
                Canvas(it).drawBitmap(content, 0f, 0f, null)
            }
        }

        out.parentFile?.mkdirs()
        val tmp = File(out.parentFile, "${out.name}.tmp-${Thread.currentThread().id}")
        FileOutputStream(tmp).use { stream ->
            if (asJpeg) {
                tile.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)
            } else {
                tile.compress(Bitmap.CompressFormat.PNG, 100, stream)
            }
        }
        if (tile !== content) tile.recycle()
        if (!tmp.renameTo(out)) {
            tmp.delete()
            throw IllegalStateException("Cannot write $out")
        }
    }

    /** Whether every pixel of [bitmap] is fully opaque. */
    private fun isOpaque(bitmap: Bitmap): Boolean {
        if (!bitmap.hasAlpha()) return true
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (pixel in row) if (pixel ushr 24 != 0xFF) return false
        }
        return true
    }

    private fun compressThreads() =
        (Runtime.getRuntime().availableProcessors() - 1).coerceIn(1, MAX_COMPRESS_THREADS)

    private class TooLargeException(message: String) : Exception(message)

    private fun ceilDiv(a: Int, b: Int) = (a + b - 1) / b

    private companion object {
        const val CHANNEL = "custom_map_marker/tiles"
        const val TILE_SIZE = 256
        const val JPEG_QUALITY = 88
        const val THREADS = 3
        const val MAX_COMPRESS_THREADS = 4
        const val IN_FLIGHT = 16
    }
}
