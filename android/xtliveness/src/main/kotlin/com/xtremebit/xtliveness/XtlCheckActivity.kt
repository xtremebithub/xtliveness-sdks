package com.xtremebit.xtliveness

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContract
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

/** What to start: from `POST /v1/sessions` on your server. */
data class XtlRequest(val checkUrl: String, val sdkToken: String, val allowInsecureHttp: Boolean = false)

/**
 * Use with the Activity Result API:
 *
 *     val check = registerForActivityResult(XtlCheckContract()) { result -> when (result) { is XtlResult.Completed -> askYourServer(result.sessionId); ... } }
 *     check.launch(XtlRequest(session.checkUrl, session.sdkToken))
 */
class XtlCheckContract : ActivityResultContract<XtlRequest, XtlResult>() {
    override fun createIntent(context: Context, input: XtlRequest): Intent =
        Intent(context, XtlCheckActivity::class.java)
            .putExtra(XtlCheckActivity.EXTRA_URL, input.checkUrl)
            .putExtra(XtlCheckActivity.EXTRA_TOKEN, input.sdkToken)
            .putExtra(XtlCheckActivity.EXTRA_INSECURE, input.allowInsecureHttp)

    override fun parseResult(resultCode: Int, intent: Intent?): XtlResult {
        if (intent == null) return XtlResult.Cancelled
        return when (intent.getStringExtra(XtlCheckActivity.EXTRA_STATUS)) {
            "completed" -> XtlResult.Completed(intent.getStringExtra(XtlCheckActivity.EXTRA_SESSION) ?: "")
            "error" -> XtlResult.Error(intent.getStringExtra(XtlCheckActivity.EXTRA_CODE) ?: "error")
            else -> XtlResult.Cancelled
        }
    }
}

/** A full-screen page that asks for the camera, runs the check and returns the result. Back counts as cancelled. */
class XtlCheckActivity : ComponentActivity() {

    private lateinit var view: XtlCheckView
    private var finished = false

    private val askCamera = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) begin() else end(XtlResult.Error("camera_denied"))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        view = XtlCheckView(this)
        setContentView(view)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = end(XtlResult.Cancelled)
        })
        if (savedInstanceState != null) { end(XtlResult.Cancelled); return }   // after a restart the one-time token is spent; the app starts a new check
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) begin() else askCamera.launch(Manifest.permission.CAMERA)
    }

    private fun begin() {
        view.start(
            intent.getStringExtra(EXTRA_URL) ?: "",
            intent.getStringExtra(EXTRA_TOKEN) ?: "",
            intent.getBooleanExtra(EXTRA_INSECURE, false),
        ) { end(it) }
    }

    private fun end(r: XtlResult) {
        if (finished) return
        finished = true
        val out = Intent()
        when (r) {
            is XtlResult.Completed -> out.putExtra(EXTRA_STATUS, "completed").putExtra(EXTRA_SESSION, r.sessionId)
            is XtlResult.Error -> out.putExtra(EXTRA_STATUS, "error").putExtra(EXTRA_CODE, r.code)
            XtlResult.Cancelled -> out.putExtra(EXTRA_STATUS, "cancelled")
        }
        setResult(RESULT_OK, out)
        finish()
    }

    companion object {
        internal const val EXTRA_URL = "xtl.checkUrl"
        internal const val EXTRA_TOKEN = "xtl.sdkToken"
        internal const val EXTRA_INSECURE = "xtl.insecure"
        internal const val EXTRA_STATUS = "xtl.status"
        internal const val EXTRA_SESSION = "xtl.sessionId"
        internal const val EXTRA_CODE = "xtl.code"
    }
}