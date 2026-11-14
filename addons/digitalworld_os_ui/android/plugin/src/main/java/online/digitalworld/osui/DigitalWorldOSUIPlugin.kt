package online.digitalworld.osui

import android.app.Activity
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import kotlin.math.roundToInt

/**
 * Displays a bundled OS preview only inside the phone-screen rectangle.
 * The transparent parent leaves the rest of the Godot worksite interactive.
 */
class DigitalWorldOSUIPlugin(godot: Godot) : GodotPlugin(godot) {
    private var hostActivity: Activity? = null
    private var overlay: FrameLayout? = null
    private var webView: WebView? = null
    private var loadedHtml: String = ""
    private var latestStateJson: String = "{}"
    private var pendingEvent: String = ""
    private val eventLock = Any()

    override fun getPluginName(): String = "DigitalWorldOSUI"
    override fun shouldBeOnTop(): Boolean = true

    override fun onMainCreate(activity: Activity): View {
        hostActivity = activity
        return FrameLayout(activity).apply {
            clipChildren = false
            clipToPadding = false
            setBackgroundColor(Color.TRANSPARENT)
            visibility = View.GONE
            isClickable = false
            isFocusable = false
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            overlay = this
        }
    }

    override fun onMainPause() {
        runOnUiThread { webView?.onPause() }
    }

    override fun onMainResume() {
        runOnUiThread { webView?.onResume() }
    }

    override fun onMainDestroy() {
        runOnUiThread {
            webView?.let { page ->
                (page.parent as? ViewGroup)?.removeView(page)
                page.stopLoading()
                page.removeJavascriptInterface("DigitalWorldOS")
                page.destroy()
            }
            webView = null
            overlay = null
            hostActivity = null
            loadedHtml = ""
            synchronized(eventLock) { pendingEvent = "" }
        }
    }

    @UsedByGodot
    fun showHtml(
        html: String,
        stateJson: String,
        leftRatio: Float,
        topRatio: Float,
        widthRatio: Float,
        heightRatio: Float
    ) {
        latestStateJson = stateJson
        runOnUiThread {
            val container = overlay ?: return@runOnUiThread
            val page = ensureWebView() ?: return@runOnUiThread
            container.visibility = View.VISIBLE
            page.visibility = View.VISIBLE
            applyFrame(leftRatio, topRatio, widthRatio, heightRatio)
            if (loadedHtml != html) {
                loadedHtml = html
                page.loadDataWithBaseURL(
                    "https://digitalworld.local/", html, "text/html", "UTF-8", null
                )
            } else {
                applyStateToPage()
            }
        }
    }

    @UsedByGodot
    fun showUi() {
        runOnUiThread {
            overlay?.visibility = View.VISIBLE
            webView?.visibility = View.VISIBLE
            applyStateToPage()
        }
    }

    @UsedByGodot
    fun hideUi() {
        runOnUiThread { overlay?.visibility = View.GONE }
    }

    @UsedByGodot
    fun updateFrame(leftRatio: Float, topRatio: Float, widthRatio: Float, heightRatio: Float) {
        runOnUiThread { applyFrame(leftRatio, topRatio, widthRatio, heightRatio) }
    }

    @UsedByGodot
    fun updateState(stateJson: String) {
        latestStateJson = stateJson
        runOnUiThread { applyStateToPage() }
    }

    /** Godot polls the one-item event queue; WebView never calls Godot directly. */
    @UsedByGodot
    fun consumeEvent(): String {
        synchronized(eventLock) {
            val event = pendingEvent
            pendingEvent = ""
            return event
        }
    }

    private fun ensureWebView(): WebView? {
        val activity = hostActivity ?: return null
        val container = overlay ?: return null
        if (webView != null) return webView

        val page = WebView(activity).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            isFocusable = true
            isFocusableInTouchMode = true
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = false
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.setSupportMultipleWindows(false)
            settings.setSupportZoom(false)
            settings.builtInZoomControls = false
            settings.displayZoomControls = false
            settings.blockNetworkLoads = true
            settings.mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW
            addJavascriptInterface(PageBridge(), "DigitalWorldOS")
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?
                ): Boolean = true

                override fun onPageFinished(view: WebView?, url: String?) {
                    applyStateToPage()
                }
            }
        }

        container.addView(page, FrameLayout.LayoutParams(1, 1, Gravity.TOP or Gravity.LEFT))
        webView = page
        return page
    }

    private fun applyFrame(
        leftRatio: Float,
        topRatio: Float,
        widthRatio: Float,
        heightRatio: Float
    ) {
        val container = overlay ?: return
        val page = webView ?: return
        if (container.width <= 0 || container.height <= 0) {
            container.post { applyFrame(leftRatio, topRatio, widthRatio, heightRatio) }
            return
        }

        val left = (leftRatio.coerceIn(0f, 1f) * container.width).roundToInt()
        val top = (topRatio.coerceIn(0f, 1f) * container.height).roundToInt()
        val width = (widthRatio.coerceIn(0f, 1f) * container.width).roundToInt().coerceAtLeast(1)
        val height = (heightRatio.coerceIn(0f, 1f) * container.height).roundToInt().coerceAtLeast(1)
        val params = (page.layoutParams as? FrameLayout.LayoutParams)
            ?: FrameLayout.LayoutParams(width, height)
        params.gravity = Gravity.TOP or Gravity.LEFT
        params.leftMargin = left
        params.topMargin = top
        params.width = width
        params.height = height
        page.layoutParams = params
    }

    private fun applyStateToPage() {
        val page = webView ?: return
        val json = latestStateJson.ifBlank { "{}" }
        page.evaluateJavascript(
            "window.DigitalWorldOSPreview && window.DigitalWorldOSPreview.applyState($json);",
            null
        )
    }

    private inner class PageBridge {
        @JavascriptInterface
        fun postMessage(message: String) {
            if (message.length > 1024) return
            synchronized(eventLock) { pendingEvent = message }
        }
    }
}
