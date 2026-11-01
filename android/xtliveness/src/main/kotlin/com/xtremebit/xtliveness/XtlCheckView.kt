package com.xtremebit.xtliveness

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.util.AttributeSet
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.content.ContextCompat

/**
 * The face check, inside your own layout. The app needs the CAMERA permission already granted ([XtlCheckActivity] asks for it for you;
 * with this view, ask first). [start] takes what `POST /v1/sessions` on YOUR server returned; never call that from the app (it needs your API key).
 * The token works once. The listener runs once, on the main thread.
 */
class XtlCheckView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : FrameLayout(context, attrs) {

    private var web: WebView? = null
    private var done = false
    private var onResult: ((XtlResult) -> Unit)? = null

    @SuppressLint("SetJavaScriptEnabled")
    fun start(checkUrl: String, sdkToken: String, allowInsecureHttp: Boolean = false, onResult: (XtlResult) -> Unit) {
        check(web == null) { "a check is already running in this view" }
        this.onResult = onResult
        val address = try {
            parseCheckUrl(checkUrl, allowInsecureHttp)
        } catch (e: IllegalArgumentException) {
            finish(XtlResult.Error("invalid_check_address")); return
        }
        val url = try {
            address.loadUrl(sdkToken)
        } catch (e: IllegalArgumentException) {
            finish(XtlResult.Error("missing_token")); return
        }
        if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            finish(XtlResult.Error("camera_denied")); return
        }

        val origin = address.origin
        val wv = WebView(context)
        wv.setBackgroundColor(Color.WHITE)
        wv.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = false
            allowContentAccess = false
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            setGeolocationEnabled(false)
            cacheMode = WebSettings.LOAD_NO_CACHE
        }
        wv.addJavascriptInterface(Bridge(address.sessionId), "XtlBridge")
        wv.webViewClient = object : WebViewClient() {
            // the page stays on the check's own address; anything else is refused
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean = originOf(request.url.toString()) != origin

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) finish(XtlResult.Error("load_failed"))
            }

            override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, errorResponse: WebResourceResponse) {
                if (request.isForMainFrame) finish(XtlResult.Error("load_failed"))
            }
        }
        wv.webChromeClient = object : WebChromeClient() {
            // only the check's own origin, and only the camera
            override fun onPermissionRequest(request: PermissionRequest) {
                val camera = request.resources.filter { it == PermissionRequest.RESOURCE_VIDEO_CAPTURE }
                if (originOf(request.origin.toString()) == origin && camera.isNotEmpty()) request.grant(camera.toTypedArray()) else request.deny()
            }
        }
        web = wv
        addView(wv, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        wv.loadUrl(url)
    }

    /** The check page reports through a channel called XtlBridge. */
    private inner class Bridge(private val sessionId: String) {
        @JavascriptInterface
        fun postMessage(message: String) {
            val r = parseMessage(message, sessionId) ?: return
            post { finish(r) }   // this runs on a WebView thread
        }
    }

    private fun finish(r: XtlResult) {
        if (done) return
        done = true
        onResult?.invoke(r)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        web?.let {
            removeView(it)
            it.stopLoading()
            it.removeJavascriptInterface("XtlBridge")
            it.destroy()
        }
        web = null
    }
}
