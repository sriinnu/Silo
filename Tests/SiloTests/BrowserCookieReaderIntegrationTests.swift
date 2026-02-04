import Foundation
import XCTest
@testable import Silo

final class BrowserCookieReaderIntegrationTests: XCTestCase {
    func testChromiumReaderReadsPlainValue() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("Cookies")
        let creationUtc: Int64 = 1_650_000_000 * 1_000_000
        let lastAccessUtc: Int64 = 1_650_000_500 * 1_000_000
        try CookieTestFixtures.createChromiumDatabase(
            at: dbURL,
            value: "abc123",
            creationUtc: creationUtc,
            lastAccessUtc: lastAccessUtc,
            priority: 2,
            isSameParty: true,
            partitionKey: "example.com")

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
        XCTAssertEqual(records.first?.createdAt, ChromiumCookieReader.date(fromChromiumTimestamp: creationUtc))
        XCTAssertEqual(records.first?.lastAccessedAt, ChromiumCookieReader.date(fromChromiumTimestamp: lastAccessUtc))
        XCTAssertEqual(records.first?.priority, BrowserCookiePriority.high)
        XCTAssertEqual(records.first?.partitionKey, "example.com")
        XCTAssertEqual(records.first?.isSameParty, true)
        #endif
    }

    func testFirefoxReaderReadsPlainValue() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("cookies.sqlite")
        let creationTime: Int64 = 1_650_100_000 * 1_000_000
        let lastAccessed: Int64 = 1_650_100_500 * 1_000_000
        try CookieTestFixtures.createFirefoxDatabase(
            at: dbURL,
            value: "dark",
            creationTime: creationTime,
            lastAccessed: lastAccessed,
            priority: 1,
            partitionKey: "example.com",
            isSameParty: false)

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
        XCTAssertEqual(records.first?.createdAt, Date(timeIntervalSince1970: Double(creationTime) / 1_000_000))
        XCTAssertEqual(records.first?.lastAccessedAt, Date(timeIntervalSince1970: Double(lastAccessed) / 1_000_000))
        XCTAssertEqual(records.first?.priority, BrowserCookiePriority.medium)
        XCTAssertEqual(records.first?.partitionKey, "example.com")
        XCTAssertEqual(records.first?.isSameParty, false)
    }

    #if os(macOS)
    func testSafariReaderParsesBinaryCookies() throws {
        guard let cookiesURL = Bundle.module.url(
            forResource: "safari",
            withExtension: "binarycookies",
            subdirectory: "Fixtures") else {
            return XCTFail("Missing Safari fixture file.")
        }

        let records = try BinaryCookiesReader().readCookies(from: cookiesURL)
        let expectedExpires = Date(timeIntervalSince1970: 1_700_000_000)
        let expectedCreatedAt = Date(timeIntervalSince1970: 1_650_000_000)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.domain, "example.com")
        XCTAssertEqual(records.first?.name, "token")
        XCTAssertEqual(records.first?.value, "abc")
        XCTAssertEqual(records.first?.isSecure, true)
        XCTAssertEqual(records.first?.isHTTPOnly, true)
        XCTAssertEqual(records.first?.expires, expectedExpires)
        XCTAssertEqual(records.first?.createdAt, expectedCreatedAt)
    }

    func testSafariReaderParsesRealWorldCookiesWhenAvailable() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home
                .appendingPathComponent("Library")
                .appendingPathComponent("Cookies")
                .appendingPathComponent("Cookies.binarycookies"),
            home
                .appendingPathComponent("Library")
                .appendingPathComponent("Containers")
                .appendingPathComponent("com.apple.Safari")
                .appendingPathComponent("Data")
                .appendingPathComponent("Library")
                .appendingPathComponent("Cookies")
                .appendingPathComponent("Cookies.binarycookies"),
        ]
        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard let url = existing.first else {
            throw XCTSkip("No real-world Safari cookies file found.")
        }

        do {
            let records = try BinaryCookiesReader().readCookies(from: url)
            if !records.isEmpty {
                XCTAssertTrue(records.allSatisfy { !$0.domain.isEmpty && !$0.name.isEmpty })
            }
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw XCTSkip("Safari cookies not readable (Full Disk Access may be required).")
        }
    }
    #endif

    #if os(iOS)
    func testIOSOnlyReturnsWebKitStores() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cookiesURL = tempDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Cookies")
            .appendingPathComponent("Cookies.binarycookies")
        try FileManager.default.createDirectory(
            at: cookiesURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let data = CookieTestFixtures.makeSafariBinaryCookies(
            domain: "example.com",
            name: "token",
            path: "/",
            value: "abc",
            expires: Date(timeIntervalSince1970: 1_700_000_000),
            isSecure: true,
            isHTTPOnly: true)
        try data.write(to: cookiesURL)

        let config = BrowserCookieClient.Configuration(homeDirectories: [tempDir])
        let client = BrowserCookieClient(configuration: config)

        XCTAssertEqual(client.stores(for: .safari).count, 1)
        XCTAssertTrue(client.stores(for: .chrome).isEmpty)
    }
    #endif
}
