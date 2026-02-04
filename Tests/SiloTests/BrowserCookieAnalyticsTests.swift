import Foundation
import XCTest
@testable import Silo

final class BrowserCookieAnalyticsTests: XCTestCase {
    private func makeRecord(
        domain: String,
        name: String,
        value: String,
        expires: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        isHostOnly: Bool = true,
        sameSite: BrowserCookieSameSite? = nil,
        partitionKey: String? = nil,
        isSameParty: Bool? = nil) -> BrowserCookieRecord
    {
        BrowserCookieRecord(
            domain: domain,
            name: name,
            path: "/",
            value: value,
            expires: expires,
            createdAt: nil,
            lastAccessedAt: nil,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            isHostOnly: isHostOnly,
            sameSite: sameSite,
            priority: nil,
            partitionKey: partitionKey,
            isSameParty: isSameParty)
    }

    func testAnalyticsSummaryCounts() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let records = [
            makeRecord(
                domain: "example.com",
                name: "a",
                value: "1",
                expires: now.addingTimeInterval(60),
                isSecure: true,
                isHTTPOnly: true,
                isHostOnly: true,
                sameSite: .lax,
                partitionKey: "example.com",
                isSameParty: true),
            makeRecord(
                domain: "example.com",
                name: "b",
                value: "2",
                expires: nil,
                isSecure: false,
                isHTTPOnly: false,
                isHostOnly: false,
                sameSite: nil),
            makeRecord(
                domain: "api.example.com",
                name: "c",
                value: "3",
                expires: now.addingTimeInterval(-60),
                isSecure: true,
                isHTTPOnly: false,
                isHostOnly: true,
                sameSite: .strict),
        ]

        let analytics = BrowserCookieAnalytics(
            records: records,
            referenceDate: now,
            expiringSoonInterval: 120,
            topDomainLimit: 2)

        XCTAssertEqual(analytics.totalCount, 3)
        XCTAssertEqual(analytics.uniqueDomainCount, 2)
        XCTAssertEqual(analytics.sessionCount, 1)
        XCTAssertEqual(analytics.persistentCount, 2)
        XCTAssertEqual(analytics.secureCount, 2)
        XCTAssertEqual(analytics.httpOnlyCount, 1)
        XCTAssertEqual(analytics.hostOnlyCount, 2)
        XCTAssertEqual(analytics.partitionedCount, 1)
        XCTAssertEqual(analytics.samePartyCount, 1)
        XCTAssertEqual(analytics.expiredCount, 1)
        XCTAssertEqual(analytics.expiringSoonCount, 1)
        XCTAssertEqual(analytics.sameSiteCounts.lax, 1)
        XCTAssertEqual(analytics.sameSiteCounts.strict, 1)
        XCTAssertEqual(analytics.sameSiteCounts.none, 0)
        XCTAssertEqual(analytics.sameSiteCounts.unspecified, 1)
        XCTAssertEqual(analytics.topDomains.first?.domain, "example.com")
        XCTAssertEqual(analytics.topDomains.first?.count, 2)
        XCTAssertEqual(analytics.earliestExpiry, now.addingTimeInterval(-60))
        XCTAssertEqual(analytics.latestExpiry, now.addingTimeInterval(60))
    }

    func testSyncPlanDetectsChangesAndCollisions() {
        let existing = [
            makeRecord(domain: "example.com", name: "sid", value: "old"),
            makeRecord(domain: "example.com", name: "pref", value: "1"),
        ]

        let incoming = [
            makeRecord(domain: "example.com", name: "sid", value: "new"),
            makeRecord(domain: "example.com", name: "new", value: "2"),
            makeRecord(domain: "dup.example.com", name: "dup", value: "a"),
            makeRecord(domain: "dup.example.com", name: "dup", value: "b"),
        ]

        let plan = BrowserCookieSync.plan(existing: existing, incoming: incoming)

        XCTAssertEqual(plan.additions.count, 1)
        XCTAssertEqual(plan.deletions.count, 1)
        XCTAssertEqual(plan.updates.count, 1)
        XCTAssertEqual(plan.unchanged.count, 0)
        XCTAssertEqual(plan.collisions.count, 1)
        XCTAssertEqual(plan.updates.first?.existing.value, "old")
        XCTAssertEqual(plan.updates.first?.incoming.value, "new")
        XCTAssertEqual(plan.deletions.first?.name, "pref")
        XCTAssertEqual(plan.additions.first?.name, "new")
    }
}
