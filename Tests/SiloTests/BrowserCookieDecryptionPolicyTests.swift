import Foundation
import XCTest
@testable import Silo

final class BrowserCookieDecryptionPolicyTests: XCTestCase {
    private struct FailingDecryptor: ChromiumCookieDecrypting {
        let hasKey: Bool = true
        func decrypt(data: Data) -> String? { nil }
    }

    func testBestEffortAllowsPartialDecryptions() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("Cookies")
        try CookieTestFixtures.createChromiumDatabase(at: dbURL, value: "ok")

        let encryptedValue = Data("v10".utf8) + Data(repeating: 0x99, count: 16)
        try CookieTestFixtures.insertChromiumCookie(
            into: dbURL,
            name: "secret",
            value: "",
            encryptedValue: encryptedValue)

        let store = BrowserCookieStore(
            browser: .chrome,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .primary,
            label: "Default",
            databaseURL: dbURL)

        let reader = ChromiumCookieReader()
        let records = try reader.readCookies(
            store: store,
            browser: .chrome,
            decryptor: FailingDecryptor(),
            decryptionFailurePolicy: .bestEffort,
            requireKeyForEncrypted: false)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.value, "ok")
    }

    func testStrictFailsOnAnyDecryptionFailure() throws {
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("Cookies")
        try CookieTestFixtures.createChromiumDatabase(at: dbURL, value: "ok")

        let encryptedValue = Data("v10".utf8) + Data(repeating: 0x99, count: 16)
        try CookieTestFixtures.insertChromiumCookie(
            into: dbURL,
            name: "secret",
            value: "",
            encryptedValue: encryptedValue)

        let store = BrowserCookieStore(
            browser: .chrome,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .primary,
            label: "Default",
            databaseURL: dbURL)

        let reader = ChromiumCookieReader()
        XCTAssertThrowsError(try reader.readCookies(
            store: store,
            browser: .chrome,
            decryptor: FailingDecryptor(),
            decryptionFailurePolicy: .strict,
            requireKeyForEncrypted: false)) { error in
                guard let cookieError = error as? BrowserCookieError else {
                    return XCTFail("Unexpected error type: \(error)")
                }
                guard case let .loadFailed(browser, _) = cookieError else {
                    return XCTFail("Expected loadFailed error")
                }
                XCTAssertEqual(browser, .chrome)
            }
    }
}
