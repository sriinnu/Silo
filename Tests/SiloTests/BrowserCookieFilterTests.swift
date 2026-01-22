import XCTest
@testable import Silo

final class BrowserCookieFilterTests: XCTestCase {
    private func makeRecord(
        domain: String,
        path: String = "/",
        expires: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        isHostOnly: Bool? = nil,
        sameSite: BrowserCookieSameSite? = nil) -> BrowserCookieRecord
    {
        BrowserCookieRecord(
            domain: domain,
            name: "sid",
            path: path,
            value: "value",
            expires: expires,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            isHostOnly: isHostOnly,
            sameSite: sameSite)
    }

    func testHostOnlyInference() {
        let hostOnly = makeRecord(domain: "example.com")
        XCTAssertTrue(hostOnly.isHostOnly)

        let domainCookie = makeRecord(domain: ".example.com")
        XCTAssertFalse(domainCookie.isHostOnly)

        let override = makeRecord(domain: ".example.com", isHostOnly: true)
        XCTAssertTrue(override.isHostOnly)
    }

    func testDomainSuffixFiltering() throws {
        let records = [
            makeRecord(domain: "api.example.com"),
            makeRecord(domain: "example.com"),
            makeRecord(domain: "example.org"),
        ]
        let query = BrowserCookieQuery(domains: ["example.com"], domainMatch: .suffix)
        let filtered = try BrowserCookieClient.apply(query: query, to: records)
        XCTAssertEqual(filtered.count, 2)
    }

    func testRegexDomainFiltering() throws {
        let records = [
            makeRecord(domain: "api.example.com"),
            makeRecord(domain: "example.org"),
        ]
        let query = BrowserCookieQuery(domainPattern: ".*\\.example\\.com$", useRegex: true)
        let filtered = try BrowserCookieClient.apply(query: query, to: records)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.domain, "api.example.com")
    }

    func testPathPrefixFiltering() throws {
        let records = [
            makeRecord(domain: "example.com", path: "/api/v1"),
            makeRecord(domain: "example.com", path: "/admin"),
            makeRecord(domain: "example.com", path: "/docs"),
        ]
        let query = BrowserCookieQuery(paths: ["/api", "/admin"], pathMatch: .prefix)
        let filtered = try BrowserCookieClient.apply(query: query, to: records)
        XCTAssertEqual(filtered.count, 2)
    }

    func testExpiryAndSessionFiltering() throws {
        let now = Date()
        let expired = makeRecord(domain: "example.com", expires: now.addingTimeInterval(-60))
        let session = makeRecord(domain: "example.com", expires: nil)
        let future = makeRecord(domain: "example.com", expires: now.addingTimeInterval(60))
        let query = BrowserCookieQuery(excludeSession: true, includeExpired: false, referenceDate: now)
        let filtered = try BrowserCookieClient.apply(query: query, to: [expired, session, future])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.expires, future.expires)
    }

    func testSecureAndHttpOnlyFiltering() throws {
        let secureOnly = makeRecord(domain: "example.com", isSecure: true, isHTTPOnly: true)
        let insecure = makeRecord(domain: "example.com", isSecure: false, isHTTPOnly: true)
        let nonHttpOnly = makeRecord(domain: "example.com", isSecure: true, isHTTPOnly: false)
        let query = BrowserCookieQuery(secureOnly: true, httpOnlyOnly: true)
        let filtered = try BrowserCookieClient.apply(query: query, to: [secureOnly, insecure, nonHttpOnly])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, secureOnly.name)
    }

    func testSameSiteFiltering() throws {
        let lax = makeRecord(domain: "example.com", sameSite: .lax)
        let strict = makeRecord(domain: "example.com", sameSite: .strict)
        let query = BrowserCookieQuery(sameSite: .strict)
        let filtered = try BrowserCookieClient.apply(query: query, to: [lax, strict])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.sameSite, .strict)
    }
}
