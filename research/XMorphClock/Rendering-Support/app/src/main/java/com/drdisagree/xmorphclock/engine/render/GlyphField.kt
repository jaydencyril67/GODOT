package com.drdisagree.xmorphclock.engine.render

import android.graphics.BitmapShader

internal class GlyphField(
    val depthShader: BitmapShader,
    val normalXShader: BitmapShader,
    val normalYShader: BitmapShader,
    val originX: Float,
    val originY: Float,
    val scale: Float,
    val depth: Float
)
