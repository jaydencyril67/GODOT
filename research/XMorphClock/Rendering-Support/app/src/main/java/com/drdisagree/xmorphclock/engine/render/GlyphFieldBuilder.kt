package com.drdisagree.xmorphclock.engine.render

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.graphics.createBitmap
import java.nio.ByteBuffer
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal object GlyphFieldBuilder {

    private const val SIDE = 512f
    private const val PAD = 4
    private const val INSIDE = 128
    private const val FAR = 1e20f
    private const val LEVELS = 255f
    private const val HALF = 0.5f
    private const val SMOOTH_RADIUS = 2
    private const val SMOOTH_PASSES = 2
    private const val MIN_SLOPE = 1e-4f

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    fun build(path: Path, bounds: RectF): GlyphField? {
        val longest = max(bounds.width(), bounds.height())
        if (longest <= 0f) return null
        val scale = SIDE / longest
        val width = ceil(bounds.width() * scale).toInt() + PAD * 2
        val height = ceil(bounds.height() * scale).toInt() + PAD * 2
        val mask = createBitmap(width, height, Bitmap.Config.ALPHA_8)
        Canvas(mask).apply {
            translate(PAD.toFloat(), PAD.toFloat())
            scale(scale, scale)
            translate(-bounds.left, -bounds.top)
            drawPath(path, paint)
        }
        val stride = mask.rowBytes
        val pixels = ByteArray(stride * height)
        mask.copyPixelsToBuffer(ByteBuffer.wrap(pixels))
        mask.recycle()
        val count = width * height
        val coverage = FloatArray(count)
        for (y in 0 until height) {
            for (x in 0 until width) coverage[y * width + x] = (pixels[y * stride + x].toInt() and 0xFF) / LEVELS
        }
        val inside = FloatArray(count) { if (coverage[it] * LEVELS >= INSIDE) FAR else 0f }
        val outside = FloatArray(count) { if (coverage[it] * LEVELS >= INSIDE) 0f else FAR }
        transform(inside, width, height)
        transform(outside, width, height)
        val field = FloatArray(count) {
            val cover = coverage[it]
            when {
                cover > 0f && cover < 1f -> cover - HALF
                inside[it] > 0f -> sqrt(inside[it]) - HALF
                else -> HALF - sqrt(outside[it])
            }
        }
        val scratch = FloatArray(count)
        repeat(SMOOTH_PASSES) {
            smooth(field, scratch, width, height, horizontal = true)
            smooth(scratch, field, width, height, horizontal = false)
        }
        var deepest = 0f
        for (value in field) if (value > deepest) deepest = value
        if (deepest <= 0f) return null
        val depth = ByteArray(stride * height)
        val normalX = ByteArray(stride * height)
        val normalY = ByteArray(stride * height)
        for (y in 0 until height) {
            for (x in 0 until width) {
                val i = y * width + x
                val gx = field[y * width + (x + 1).coerceAtMost(width - 1)] - field[y * width + (x - 1).coerceAtLeast(0)]
                val gy = field[(y + 1).coerceAtMost(height - 1) * width + x] - field[(y - 1).coerceAtLeast(0) * width + x]
                val slope = sqrt(gx * gx + gy * gy)
                val nx = if (slope > MIN_SLOPE) -gx / slope else 0f
                val ny = if (slope > MIN_SLOPE) -gy / slope else 0f
                val o = y * stride + x
                depth[o] = level(field[i].coerceAtLeast(0f) / deepest)
                normalX[o] = level(nx * HALF + HALF)
                normalY[o] = level(ny * HALF + HALF)
            }
        }
        return GlyphField(
            shaderOf(depth, width, height),
            shaderOf(normalX, width, height),
            shaderOf(normalY, width, height),
            bounds.left - PAD / scale,
            bounds.top - PAD / scale,
            scale,
            deepest / scale
        )
    }

    private fun level(value: Float): Byte = (value * LEVELS).roundToInt().coerceIn(0, LEVELS.toInt()).toByte()

    private fun shaderOf(data: ByteArray, width: Int, height: Int): BitmapShader {
        val bitmap = createBitmap(width, height, Bitmap.Config.ALPHA_8)
        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(data))
        return BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            filterMode = BitmapShader.FILTER_MODE_LINEAR
        }
    }

    private fun smooth(source: FloatArray, target: FloatArray, width: Int, height: Int, horizontal: Boolean) {
        val lines = if (horizontal) height else width
        val length = if (horizontal) width else height
        val window = SMOOTH_RADIUS * 2 + 1
        for (line in 0 until lines) {
            fun at(position: Int): Float {
                val p = position.coerceIn(0, length - 1)
                return if (horizontal) source[line * width + p] else source[p * width + line]
            }
            var sum = 0f
            for (offset in -SMOOTH_RADIUS..SMOOTH_RADIUS) sum += at(offset)
            for (position in 0 until length) {
                val index = if (horizontal) line * width + position else position * width + line
                target[index] = sum / window
                sum += at(position + SMOOTH_RADIUS + 1) - at(position - SMOOTH_RADIUS)
            }
        }
    }

    private fun transform(grid: FloatArray, width: Int, height: Int) {
        val size = max(width, height)
        val line = FloatArray(size)
        val out = FloatArray(size)
        val hull = IntArray(size)
        val bounds = FloatArray(size + 1)
        for (x in 0 until width) {
            for (y in 0 until height) line[y] = grid[y * width + x]
            pass(line, height, out, hull, bounds)
            for (y in 0 until height) grid[y * width + x] = out[y]
        }
        for (y in 0 until height) {
            for (x in 0 until width) line[x] = grid[y * width + x]
            pass(line, width, out, hull, bounds)
            for (x in 0 until width) grid[y * width + x] = out[x]
        }
    }

    private fun pass(source: FloatArray, count: Int, out: FloatArray, hull: IntArray, bounds: FloatArray) {
        var k = 0
        hull[0] = 0
        bounds[0] = -FAR
        bounds[1] = FAR
        for (q in 1 until count) {
            var s = intersection(source, q, hull[k])
            while (s <= bounds[k]) {
                k--
                s = intersection(source, q, hull[k])
            }
            k++
            hull[k] = q
            bounds[k] = s
            bounds[k + 1] = FAR
        }
        k = 0
        for (q in 0 until count) {
            while (bounds[k + 1] < q) k++
            val d = (q - hull[k]).toFloat()
            out[q] = d * d + source[hull[k]]
        }
    }

    private fun intersection(source: FloatArray, q: Int, p: Int): Float =
        ((source[q] - source[p]) + q.toFloat() * q - p.toFloat() * p) / (2f * q - 2f * p)
}
