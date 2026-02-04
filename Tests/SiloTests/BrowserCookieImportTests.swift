import Foundation
import XCTest
@testable import Silo

final class BrowserCookieImportTests: XCTestCase {
    func testJSONImportRoundTripPreservesHostOnly() throws {
        let record = BrowserCookieRecord(
            domain: "example.com",
            name: "session",
            path: "/",
            value: "abc123",
            expires: nil,
            isSecure: true,
            isHTTPOnly: true,
            isHostOnly: false)

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
        let imported = try BrowserCookieImport(data: data)

        XCTAssertEqual(imported.schemaVersion, 1)
        XCTAssertEqual(imported.stores.count, 1)
        XCTAssertEqual(imported.stores.first?.store.browser, .chrome)
        let importedRecord = imported.records.first
        XCTAssertEqual(importedRecord?.domain, "example.com")
        XCTAssertEqual(importedRecord?.isHostOnly, false)
    }

    func testJSONImportDefaultHostOnlyFallback() throws {
        let json = """
        {
          "generatedAt": "2024-01-01T00:00:00Z",
          "stores": [
            {
              "browser": "chrome",
              "profileId": "Default",
              "profileName": "Default",
              "kind": "primary",
              "label": "Default",
              "records": [
                {
                  "domain": "example.com",
                  "name": "sid",
                  "path": "/",
                  "value": "abc",
                  "isSecure": true,
                  "isHTTPOnly": false
                }
              ]
            }
          ]
        }
        """

        let data = Data(json.utf8)

        let defaultImport = try BrowserCookieImport(data: data)
        XCTAssertEqual(defaultImport.schemaVersion, 1)
        XCTAssertEqual(defaultImport.records.first?.isHostOnly, true)

        let relaxedImport = try BrowserCookieImport(
            data: data,
            options: BrowserCookieImportOptions(defaultHostOnly: false))
        XCTAssertEqual(relaxedImport.records.first?.isHostOnly, false)
    }
}
