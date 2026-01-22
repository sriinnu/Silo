import Foundation
import XCTest
@testable import Silo

final class BrowserCookieReaderIntegrationTests: XCTestCase {
    func testChromiumReaderReadsPlainValue() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("Cookies")
        try CookieTestFixtures.createChromiumDatabase(at: dbURL, value: "abc123")

        let store = BrowserCookieStore(
            browser: .chrome,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .primary,
            label: "Default",
            databaseURL: dbURL)

        #if os(macOS)
        let reader = MacOSChromiumCookieReader()
        let records = try reader.readCookies(store: store)
        #elseif os(Linux)
        let reader = LinuxChromiumCookieReader()
        let records = try reader.readCookies(store: store)
        #elseif os(Windows)
        let reader = WindowsChromiumCookieReader()
        let records = try reader.readCookies(store: store)
        #else
        let records: [BrowserCookieRecord] = []
        #endif

        #if !os(macOS) && !os(Linux) && !os(Windows)
        XCTAssertTrue(records.isEmpty)
        #else
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.domain, "example.com")
        XCTAssertEqual(records.first?.name, "session")
        XCTAssertEqual(records.first?.value, "abc123")
        #endif
    }

    func testFirefoxReaderReadsPlainValue() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("cookies.sqlite")
        try CookieTestFixtures.createFirefoxDatabase(at: dbURL, value: "dark")

        let store = BrowserCookieStore(
            browser: .firefox,
            profile: BrowserProfile(id: "default", name: "default"),
            kind: .primary,
            label: "default",
            databaseURL: dbURL)

        let reader = FirefoxCookieReader()
        let records = try reader.readCookies(store: store)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.domain, "example.com")
        XCTAssertEqual(records.first?.name, "pref")
        XCTAssertEqual(records.first?.value, "dark")
        XCTAssertEqual(records.first?.isHostOnly, true)
    }

    #if os(macOS)
    func testSafariReaderParsesBinaryCookies() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cookiesURL = tempDir.appendingPathComponent("Cookies.binarycookies")
        let data = CookieTestFixtures.makeSafariBinaryCookies(
            domain: "example.com",
            name: "token",
            path: "/",
            value: "abc",
            expires: Date(timeIntervalSince1970: 1_700_000_000),
            isSecure: true,
            isHTTPOnly: true)
        try data.write(to: cookiesURL)

        let records = try BinaryCookiesReader().readCookies(from: cookiesURL)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.domain, "example.com")
        XCTAssertEqual(records.first?.name, "token")
        XCTAssertEqual(records.first?.value, "abc")
        XCTAssertEqual(records.first?.isSecure, true)
        XCTAssertEqual(records.first?.isHTTPOnly, true)
    }
    #endif
}
