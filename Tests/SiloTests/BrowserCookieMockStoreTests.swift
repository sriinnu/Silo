import Foundation
import XCTest
@testable import Silo

final class BrowserCookieMockStoreTests: XCTestCase {
    private func makeRecord(
        domain: String = "example.com",
        name: String = "sid",
        path: String = "/",
        value: String = "value",
        isHostOnly: Bool = true,
        partitionKey: String? = nil) -> BrowserCookieRecord
    {
        BrowserCookieRecord(
            domain: domain,
            name: name,
            path: path,
            value: value,
            expires: Date(timeIntervalSince1970: 4_000_000_000),
            isSecure: true,
            isHTTPOnly: true,
            isHostOnly: isHostOnly,
            sameSite: .lax,
            priority: .low,
            partitionKey: partitionKey,
            isSameParty: nil)
    }

    func testCreateUpdateDelete() throws {
        let store = BrowserCookieMockStore(browser: .firefox, label: "Mock")
        let record = makeRecord(value: "alpha")

        try store.create(record)
        XCTAssertEqual(store.allRecords().count, 1)

        XCTAssertThrowsError(try store.create(record)) { error in
            guard case BrowserCookieClient.MutationError.duplicateCookie = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let updated = makeRecord(value: "beta")
        try store.update(updated)
        XCTAssertEqual(store.allRecords().first?.value, "beta")

        let missing = makeRecord(domain: "missing.com", name: "id")
        XCTAssertThrowsError(try store.update(missing)) { error in
            guard case BrowserCookieClient.MutationError.missingCookie = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertTrue(store.delete(updated))
        XCTAssertFalse(store.delete(updated))
    }

    func testUpsertReplacesOrInserts() {
        let store = BrowserCookieMockStore(browser: .chrome, label: "Mock")
        let record = makeRecord(value: "first")
        store.upsert(record)
        XCTAssertEqual(store.allRecords().count, 1)

        let updated = makeRecord(value: "second")
        store.upsert(updated)
        XCTAssertEqual(store.allRecords().count, 1)
        XCTAssertEqual(store.allRecords().first?.value, "second")
    }

    func testDeleteMatchingQuery() throws {
        let store = BrowserCookieMockStore(browser: .chrome, label: "Mock")
        store.upsert(makeRecord(domain: "example.com", name: "a"))
        store.upsert(makeRecord(domain: "api.example.com", name: "b"))
        store.upsert(makeRecord(domain: "other.com", name: "c"))

        let query = BrowserCookieQuery(domains: ["example.com"], domainMatch: .suffix)
        let deleted = try store.delete(matching: query)
        XCTAssertEqual(deleted, 2)
        XCTAssertEqual(store.allRecords().count, 1)
        XCTAssertEqual(store.allRecords().first?.domain, "other.com")
    }

    func testRecordsMatchingQueryUsesFilters() throws {
        let store = BrowserCookieMockStore(browser: .chrome, label: "Mock")
        store.upsert(makeRecord(domain: "example.com", name: "a", path: "/api"))
        store.upsert(makeRecord(domain: "example.com", name: "b", path: "/admin"))

        let query = BrowserCookieQuery(paths: ["/api"], pathMatch: .prefix)
        let records = try store.records(matching: query)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.path, "/api")
    }
}
