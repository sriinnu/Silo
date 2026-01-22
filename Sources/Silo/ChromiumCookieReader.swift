import Foundation
import SQLite3

/// Shared Chromium cookie reader for all platforms.
/// Platform-specific decryptors are injected via `ChromiumCookieDecrypting`.
protocol ChromiumCookieDecrypting: Sendable {
    var hasKey: Bool { get }
    func decrypt(data: Data) -> String?
}

/// Reads Chromium-based cookie stores and returns normalized cookie records.
struct ChromiumCookieReader {
    func readCookies(
        store: BrowserCookieStore,
        browser: Browser,
        decryptor: ChromiumCookieDecrypting,
        decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy,
        requireKeyForEncrypted: Bool) throws -> [BrowserCookieRecord]
    {
        guard let databaseURL = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: browser,
                details: "Missing cookie database URL.")
        }

        let snapshot = SQLiteSnapshot.prepare(from: databaseURL)
        defer { snapshot.cleanup() }

        var db: OpaquePointer?
        if sqlite3_open_v2(snapshot.readURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw BrowserCookieError.loadFailed(
                browser: browser,
                details: "Unable to open cookies database.")
        }
        defer { sqlite3_close(db) }

        let query = """
        SELECT host_key, name, path, value, encrypted_value, expires_utc, is_secure, is_httponly, samesite
        FROM cookies
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw BrowserCookieError.loadFailed(
                browser: browser,
                details: "Unable to read cookies table.")
        }
        defer { sqlite3_finalize(statement) }

        var records: [BrowserCookieRecord] = []
        var usedEncryptedValues = false
        var failedDecryptions = 0

        while sqlite3_step(statement) == SQLITE_ROW {
            let hostKey = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? ""
            let name = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? ""
            let path = sqlite3_column_text(statement, 2).flatMap { String(cString: $0) } ?? ""
            let value = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) } ?? ""
            let encrypted = sqlite3_column_blob(statement, 4)
            let encryptedLength = Int(sqlite3_column_bytes(statement, 4))
            let expiresUtc = sqlite3_column_int64(statement, 5)
            let isSecure = sqlite3_column_int(statement, 6) != 0
            let isHttpOnly = sqlite3_column_int(statement, 7) != 0
            let sameSiteValue = sqlite3_column_int(statement, 8)

            let decryptedValue: String
            if value.isEmpty, let encrypted = encrypted, encryptedLength > 0 {
                usedEncryptedValues = true
                let data = Data(bytes: encrypted, count: encryptedLength)
                if let decrypted = decryptor.decrypt(data: data) {
                    decryptedValue = decrypted
                } else {
                    failedDecryptions += 1
                    continue
                }
            } else {
                decryptedValue = value
            }

            if hostKey.isEmpty || name.isEmpty {
                continue
            }

            let expires = Self.date(fromChromiumTimestamp: expiresUtc)
            let sameSite = Self.sameSite(from: sameSiteValue)

            records.append(BrowserCookieRecord(
                domain: hostKey,
                name: name,
                path: path.isEmpty ? "/" : path,
                value: decryptedValue,
                expires: expires,
                isSecure: isSecure,
                isHTTPOnly: isHttpOnly,
                sameSite: sameSite))
        }

        if usedEncryptedValues, requireKeyForEncrypted, !decryptor.hasKey {
            throw BrowserCookieError.accessDenied(
                browser: browser,
                details: "Keychain access required to decrypt cookies.")
        }

        if failedDecryptions > 0 {
            if decryptionFailurePolicy == .strict {
                throw BrowserCookieError.loadFailed(
                    browser: browser,
                    details: "Failed to decrypt \(failedDecryptions) cookie value(s).")
            }
            if usedEncryptedValues, records.isEmpty {
                throw BrowserCookieError.loadFailed(
                    browser: browser,
                    details: "Unable to decrypt cookie values.")
            }
        }

        return records
    }

    static func date(fromChromiumTimestamp timestamp: Int64) -> Date? {
        guard timestamp > 0 else { return nil }
        let seconds = Double(timestamp) / 1_000_000
        return chromiumEpoch.addingTimeInterval(seconds)
    }

    static func sameSite(from value: Int32) -> BrowserCookieSameSite? {
        switch value {
        case 1:
            return .lax
        case 2:
            return .strict
        case 3:
            return BrowserCookieSameSite.none
        default:
            return nil
        }
    }

    private static let chromiumEpoch: Date = {
        var components = DateComponents()
        components.year = 1601
        components.month = 1
        components.day = 1
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }()
}
