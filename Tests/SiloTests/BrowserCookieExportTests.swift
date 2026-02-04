import Foundation
import XCTest
@testable import Silo

final class BrowserCookieExportTests: XCTestCase {
    func testJSONExportEncodesAndDecodes() throws {
        let record = BrowserCookieRecord(
            domain: "example.com",
            name: "session",
            path: "/",
            value: "abc123",
            expires: Date(timeIntervalSince1970: 1_700_000_000),
            createdAt: Date(timeIntervalSince1970: 1_650_000_000),
            lastAccessedAt: Date(timeIntervalSince1970: 1_650_000_500),
            isSecure: true,
            isHTTPOnly: true,
            isHostOnly: true,
            sameSite: .lax,
            priority: .high,
            partitionKey: "example.com",
            isSameParty: true)

        let store = BrowserCookieStore(
            browser: .chrome,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .primary,
            label: "Default",
            databaseURL: nil)

        let export = BrowserCookieExport(
            generatedAt: Date(timeIntervalSince1970: 0),
            stores: [BrowserCookieStoreExport(store: store, records: [record])])

        let data = try export.jsonData(prettyPrinted: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BrowserCookieExport.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.stores.count, 1)
        let decodedRecord = decoded.stores.first?.records.first
        XCTAssertEqual(decodedRecord?.domain, "example.com")
        XCTAssertEqual(decodedRecord?.isHostOnly, true)
        XCTAssertEqual(decodedRecord?.priority, .high)
        XCTAssertEqual(decodedRecord?.partitionKey, "example.com")
        XCTAssertEqual(decodedRecord?.isSameParty, true)
    }
}
