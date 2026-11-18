package com.drdisagree.xmorphclock.engine.render

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.os.Build
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
internal class TextGlassRenderer {

    private val shader = RuntimeShader(GLASS)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bounds = RectF()
    private val fields = LinkedHashMap<String, GlyphField>(CACHE_SIZE, 0.75f, true)

    fun draw(canvas: Canvas, path: Path, key: String, image: Shader, alpha: Int, tint: Int, tintAmount: Float, rim: Float, refraction: Float, blur: Float, exposure: Float) {
        path.computeBounds(bounds, true)
        if (bounds.isEmpty) return
        val field = field(path, key) ?: return
        shader.setInputShader(IMAGE, image)
        shader.setInputShader(FIELD, field.depthShader)
        shader.setInputShader(NORMAL_X, field.normalXShader)
        shader.setInputShader(NORMAL_Y, field.normalYShader)
        shader.setFloatUniform(FIELD_ORIGIN, field.originX, field.originY)
        shader.setFloatUniform(FIELD_SCALE, field.scale)
        shader.setFloatUniform(DEPTH, field.depth)
        shader.setFloatUniform(REFRACTION, refraction.coerceAtMost(field.depth * MAX_REFRACTION_RATIO))
        shader.setFloatUniform(RIM_WIDTH, rim.coerceIn(MIN_RIM / field.scale, field.depth * MAX_RIM_RATIO))
        shader.setFloatUniform(BLUR, blur)
        shader.setFloatUniform(EXPOSURE, exposure.coerceIn(0f, 1f))
        shader.setFloatUniform(DISPERSION, DISPERSION_AMOUNT)
        shader.setFloatUniform(SATURATION, SATURATION_AMOUNT)
        shader.setFloatUniform(DIM, Color.red(tint) / 255f, Color.green(tint) / 255f, Color.blue(tint) / 255f, tintAmount)
        paint.shader = shader
        paint.alpha = alpha
        canvas.drawPath(path, paint)
        paint.shader = null
    }

    private fun field(path: Path, key: String): GlyphField? {
        val cacheKey = "$key|${bounds.width().toInt()}|${bounds.height().toInt()}"
        fields[cacheKey]?.let { return it }
        val built = GlyphFieldBuilder.build(path, bounds) ?: return null
        if (fields.size >= CACHE_SIZE) fields.remove(fields.keys.first())
        fields[cacheKey] = built
        return built
    }

    private companion object {
        const val IMAGE = "image"
        const val FIELD = "field"
        const val FIELD_ORIGIN = "fieldOrigin"
        const val FIELD_SCALE = "fieldScale"
        const val DEPTH = "depth"
        const val NORMAL_X = "normalX"
        const val NORMAL_Y = "normalY"
        const val REFRACTION = "refraction"
        const val RIM_WIDTH = "rimWidth"
        const val BLUR = "blur"
        const val EXPOSURE = "exposure"
        const val DISPERSION = "dispersion"
        const val SATURATION = "saturation"
        const val DIM = "dim"
        const val CACHE_SIZE = 12
        const val MAX_REFRACTION_RATIO = 1.5f
        const val MIN_RIM = 1f
        const val MAX_RIM_RATIO = 0.45f
        const val DISPERSION_AMOUNT = 0.08f
        const val SATURATION_AMOUNT = 1.15f

        const val GLASS = """
        uniform shader image;
        uniform shader field;
        uniform shader normalX;
        uniform shader normalY;
        uniform float2 fieldOrigin;
        uniform float fieldScale;
        uniform float depth;
        uniform float refraction;
        uniform float rimWidth;
        uniform float blur;
        uniform float exposure;
        uniform float dispersion;
        uniform float saturation;
        uniform float4 dim;

        half3 refracted(float2 at, float2 offset) {
            return half3(
                image.eval(at + offset * (1.0 + dispersion)).r,
                image.eval(at + offset).g,
                image.eval(at + offset * (1.0 - dispersion)).b
            );
        }

        half4 main(float2 coord) {
            float2 p = (coord - fieldOrigin) * fieldScale;
            float d = field.eval(p).a * depth;
            float2 n = float2(normalX.eval(p).a, normalY.eval(p).a) * 2.0 - 1.0;
            float len = length(n);
            float2 normal = len > 0.05 ? n / len : float2(0.0);

            float band = clamp(1.0 - d / max(depth, 0.0001), 0.0, 1.0);
            float bend = band * band * band;
            float2 offset = -normal * refraction * bend;

            half3 color = refracted(coord, offset) * 0.36;
            color += refracted(coord + float2(blur, blur), offset) * 0.16;
            color += refracted(coord + float2(-blur, blur), offset) * 0.16;
            color += refracted(coord + float2(blur, -blur), offset) * 0.16;
            color += refracted(coord + float2(-blur, -blur), offset) * 0.16;
            half luma = dot(color, half3(0.2126, 0.7152, 0.0722));
            color = clamp(mix(half3(luma), color, half(saturation)), 0.0, 1.0);
            color = mix(color, half3(dim.rgb), half(dim.a * exposure));

            float rimBand = exp(-d / rimWidth);
            float facing = dot(normal, normalize(float2(-0.5, -0.85)));
            float light = clamp(facing, 0.0, 1.0);
            float back = clamp(-facing, 0.0, 1.0);
            half lit = half(clamp(rimBand * (0.16 + 0.5 * light + 0.22 * back) + bend * 0.12 * light + 0.03, 0.0, 1.0));
            half dark = half(clamp(bend * 0.08 * back, 0.0, 1.0));
            color = clamp(color + (lit - dark) * half(exposure), 0.0, 1.0);
            return half4(color, 1.0);
        }
    """
    }
}
