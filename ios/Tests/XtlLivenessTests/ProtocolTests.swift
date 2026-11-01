import XCTest
@testable import XtlLiveness

final class ProtocolTests: XCTestCase {
    let id = "123e4567-e89b-12d3-a456-426614174000"

    func testAcceptsHttpsCheckAddress() throws {
        let a = try parseCheckURL("https://C.example.com/check/\(id)")
        XCTAssertEqual(a.origin, "https://c.example.com")
        XCTAssertEqual(a.sessionId, id)
    }

    func testHttpOnlyOnLocalhostOrWhenAllowed() throws {
        XCTAssertEqual(try parseCheckURL("http://localhost:8200/check/\(id)").origin, "http://localhost:8200")
        XCTAssertThrowsError(try parseCheckURL("http://c.example.com/check/\(id)"))
        XCTAssertEqual(try parseCheckURL("http://10.0.2.2:8200/check/\(id)", allowInsecureHTTP: true).host, "10.0.2.2")
    }

    func testRefusesOtherShapes() {
        for bad in ["https://c.example.com/check/\(id)?x=1", "https://c.example.com/check/\(id)#t=1", "https://u:p@c.example.com/check/\(id)", "javascript:alert(1)", "", "https://c.example.com/check/short"] {
            XCTAssertThrowsError(try parseCheckURL(bad), bad)
        }
    }

    func testTokenGoesInTheFragment() throws {
        let u = try parseCheckURL("https://c.example.com/check/\(id)").loadURL(sdkToken: "a b+c").absoluteString
        XCTAssertTrue(u.hasSuffix("#t=a%20b%2Bc"))
        XCTAssertFalse(u.contains("?"))
        XCTAssertThrowsError(try parseCheckURL("https://c.example.com/check/\(id)").loadURL(sdkToken: ""))
    }

    func testOriginOfIsExact() {
        XCTAssertEqual(originOf("https://C.example.com:8443/a/b?c#d"), "https://c.example.com:8443")
        XCTAssertNil(originOf("intent://x"))
        XCTAssertNotEqual(originOf("https://c.example.com.evil.net/x"), "https://c.example.com")
    }

    func testMessages() {
        XCTAssertEqual(parseMessage(#"{"type":"xtl:result","sessionId":"\#(id)","status":"completed"}"#, expectedSessionId: id), .completed(sessionId: id))
        XCTAssertEqual(parseMessage(#"{"type":"xtl:result","sessionId":"\#(id)","status":"cancelled"}"#, expectedSessionId: id), .cancelled)
        XCTAssertEqual(parseMessage(#"{"type":"xtl:result","sessionId":"\#(id)","status":"error","code":"timeout"}"#, expectedSessionId: id), .error(code: "timeout"))
        XCTAssertEqual(parseMessage(["type": "xtl:result", "sessionId": id, "status": "error"], expectedSessionId: id), .error(code: "error"))
        XCTAssertNil(parseMessage(#"{"type":"xtl:result","sessionId":"other","status":"completed"}"#, expectedSessionId: id))
        XCTAssertNil(parseMessage(#"{"type":"x","sessionId":"\#(id)","status":"completed"}"#, expectedSessionId: id))
        XCTAssertNil(parseMessage("not json", expectedSessionId: id))
    }
}
