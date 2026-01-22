import XCTest
@testable import Silo

final class CookieRedactionTests: XCTestCase {
    func testRedactsWithDefaultPrefix() {
        let record = makeRecord(value: "abcdef")
        XCTAssertEqual(record.redactedValue, "abcd...")
    }

    func testRedactsWithCustomPrefixSuffix() {
        let record = makeRecord(value: "token12345")
        XCTAssertEqual(record.redactedValue(prefix: 2, suffix: 2), "to...45")
    }

    func testRedactsShortValuesFully() {
        let record = makeRecord(value: "abc")
        XCTAssertEqual(record.redactedValue, "***")
    }

    func testRedactsEmptyValuesAsEmpty() {
        let record = makeRecord(value: "")
        XCTAssertEqual(record.redactedValue, "")
    }

    private func makeRecord(value: String) -> BrowserCookieRecord {
        BrowserCookieRecord(
            domain: "example.com",
            name: "session",
            path: "/",
            value: value,
            expires: nil,
            isSecure: false,
            isHTTPOnly: false)
    }
}
