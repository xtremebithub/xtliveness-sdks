package com.xtremebit.xtliveness

import org.json.JSONException
import org.json.JSONObject

/** What the hosted check reports. It never carries the verdict: your server learns that from the API or the webhook. */
sealed class XtlResult {
    /** The person finished the check. Ask YOUR server for the verdict (GET /v1/sessions/{sessionId}); never decide from this. */
    data class Completed(val sessionId: String) : XtlResult()

    object Cancelled : XtlResult() {
        override fun toString() = "Cancelled"
    }

    /**
     * [code] is one of: token_invalid, token_used, session_expired, session_not_open, engine_unavailable, timeout, missing_token,
     * camera_denied, load_failed, invalid_check_address, error.
     */
    data class Error(val code: String) : XtlResult()
}

/** A parsed check address. */
data class CheckAddress(val scheme: String, val host: String, val port: String?, val path: String) {
    /** scheme://host[:port], lower case */
    val origin: String get() = "$scheme://$host" + (port?.let { ":$it" } ?: "")

    val sessionId: String get() = path.substringAfterLast('/').lowercase()

    /** Where the WebView is sent. The one-time token rides in the fragment: it is never sent to a server or written to a log. */
    fun loadUrl(sdkToken: String): String {
        require(sdkToken.isNotEmpty()) { "sdkToken is required" }
        return origin + path + "#t=" + java.net.URLEncoder.encode(sdkToken, "UTF-8").replace("+", "%20")
    }
}

private val ADDRESS = Regex("^(https?)://([A-Za-z0-9.-]+)(?::(\\d{1,5}))?(/check/[0-9a-fA-F-]{36})$")

/**
 * Checks the address your server got from POST /v1/sessions. https only; plain http for localhost, or any host with [allowInsecureHttp]
 * (development against a service on your own network; never in a release). No query, no fragment, no login. Throws [IllegalArgumentException].
 */
fun parseCheckUrl(raw: String, allowInsecureHttp: Boolean = false): CheckAddress {
    val m = ADDRESS.matchEntire(raw)
        ?: throw IllegalArgumentException(if (raw.startsWith("http://", true) || raw.startsWith("https://", true)) "checkUrl is not a check address" else "checkUrl must be https")
    val scheme = m.groupValues[1].lowercase()
    val host = m.groupValues[2].lowercase()
    val local = host == "localhost" || host == "127.0.0.1"
    require(scheme == "https" || local || allowInsecureHttp) { "checkUrl must be https" }
    return CheckAddress(scheme, host, m.groups[3]?.value, m.groupValues[4])
}

private val ORIGIN = Regex("^(https?)://([^/?#@\\s]+)", RegexOption.IGNORE_CASE)

/** The origin of any address, or null when it is not an http(s) address. */
fun originOf(raw: String): String? = ORIGIN.find(raw)?.let { it.groupValues[1].lowercase() + "://" + it.groupValues[2].lowercase() }

/** Reads one message from the page's XtlBridge channel. Returns null for anything that is not a result for this session. */
fun parseMessage(raw: String, expectedSessionId: String): XtlResult? {
    val d = try { JSONObject(raw) } catch (e: JSONException) { return null }
    if (d.optString("type") != "xtl:result") return null
    val session = d.optString("sessionId")
    if (!session.equals(expectedSessionId, ignoreCase = true)) return null
    return when (d.optString("status")) {
        "completed" -> XtlResult.Completed(session)
        "cancelled" -> XtlResult.Cancelled
        "error" -> XtlResult.Error(d.optString("code").ifEmpty { "error" })
        else -> null
    }
}
