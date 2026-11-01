package com.xtremebit.xtliveness.demo

import android.os.Bundle
import android.text.InputType
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import com.xtremebit.xtliveness.XtlCheckContract
import com.xtremebit.xtliveness.XtlRequest
import com.xtremebit.xtliveness.XtlResult

/**
 * Paste the checkUrl and sdkToken your server got from POST /v1/sessions (a test key and a "scenario" make this work without AWS), then start.
 * In a real app these two values come from your own server, never from the app.
 */
class MainActivity : ComponentActivity() {
    private lateinit var out: TextView

    private val check = registerForActivityResult(XtlCheckContract()) { r ->
        out.text = when (r) {
            is XtlResult.Completed -> "Completed. Now ask YOUR server for the verdict of session ${r.sessionId}."
            XtlResult.Cancelled -> "Cancelled."
            is XtlResult.Error -> "Error: ${r.code}"
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = (16 * resources.displayMetrics.density).toInt()
        val url = EditText(this).apply { hint = "checkUrl (https://.../check/<id>)"; inputType = InputType.TYPE_TEXT_VARIATION_URI; setSingleLine() }
        val token = EditText(this).apply { hint = "sdkToken"; setSingleLine() }
        out = TextView(this)
        val start = Button(this).apply {
            text = "Start check"
            setOnClickListener { check.launch(XtlRequest(url.text.toString().trim(), token.text.toString().trim(), allowInsecureHttp = true)) }
        }
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            val w = ViewGroup.LayoutParams.MATCH_PARENT
            addView(url, LinearLayout.LayoutParams(w, ViewGroup.LayoutParams.WRAP_CONTENT))
            addView(token, LinearLayout.LayoutParams(w, ViewGroup.LayoutParams.WRAP_CONTENT))
            addView(start)
            addView(out)
        })
    }
}
