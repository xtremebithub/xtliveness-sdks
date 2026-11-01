package com.xtremebit.xtliveness

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ProtocolTest {
    private val id = "123e4567-e89b-12d3-a456-426614174000"

    @Test fun acceptsHttpsCheckAddress() {
        val a = parseCheckUrl("https://C.example.com/check/$id")
        assertEquals("https://c.example.com", a.origin)
        assertEquals(id, a.sessionId)
    }

    @Test fun httpOnlyOnLocalhostOrWhenAllowed() {
        assertEquals("http://localhost:8200", parseCheckUrl("http://localhost:8200/check/$id").origin)
        assertThrows(IllegalArgumentException::class.java) { parseCheckUrl("http://c.example.com/check/$id") }
        assertEquals("10.0.2.2", parseCheckUrl("http://10.0.2.2:8200/check/$id", allowInsecureHttp = true).host)
    }

    @Test fun refusesOtherShapes() {
        for (bad in listOf("https://c.example.com/check/$id?x=1", "https://c.example.com/check/$id#t=1", "https://u:p@c.example.com/check/$id", "javascript:alert(1)", "", "https://c.example.com/check/short")) {
            assertThrows(bad, IllegalArgumentException::class.java) { parseCheckUrl(bad) }
        }
    }

    @Test fun tokenGoesInTheFragment() {
        val u = parseCheckUrl("https://c.example.com/check/$id").loadUrl("a b+c")
        assertTrue(u.endsWith("#t=a%20b%2Bc"))
        assertTrue(!u.contains("?"))
        assertThrows(IllegalArgumentException::class.java) { parseCheckUrl("https://c.example.com/check/$id").loadUrl("") }
    }

    @Test fun originOfIsExact() {
        assertEquals("https://c.example.com:8443", originOf("https://C.example.com:8443/a/b?c#d"))
        assertNull(originOf("intent://x"))
        assertTrue(originOf("https://c.example.com.evil.net/x") != "https://c.example.com")
    }

    @Test fun messages() {
        assertEquals(XtlResult.Completed(id), parseMessage("""{"type":"xtl:result","sessionId":"$id","status":"completed"}""", id))
        assertEquals(XtlResult.Cancelled, parseMessage("""{"type":"xtl:result","sessionId":"$id","status":"cancelled"}""", id))
        assertEquals(XtlResult.Error("timeout"), parseMessage("""{"type":"xtl:result","sessionId":"$id","status":"error","code":"timeout"}""", id))
        assertEquals(XtlResult.Error("error"), parseMessage("""{"type":"xtl:result","sessionId":"$id","status":"error"}""", id))
        assertNull(parseMessage("""{"type":"xtl:result","sessionId":"other","status":"completed"}""", id))
        assertNull(parseMessage("""{"type":"x","sessionId":"$id","status":"completed"}""", id))
        assertNull(parseMessage("not json", id))
    }
}
