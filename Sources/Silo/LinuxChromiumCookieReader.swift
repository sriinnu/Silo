#if os(Linux)
import Foundation
import SQLite3
#if canImport(CryptoSwift)
import CryptoSwift
#endif

struct LinuxChromiumCookieReader {
    func readCookies(store: BrowserCookieStore) throws -> [BrowserCookieRecord] {
        guard let databaseURL = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: store.browser,
                details: "Missing cookie database URL.")
        }
        let snapshot = SQLiteSnapshot.prepare(from: databaseURL)
        defer { snapshot.cleanup() }

        var db: OpaquePointer?
        if sqlite3_open_v2(snapshot.readURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw BrowserCookieError.loadFailed(
                browser: store.browser,
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
                browser: store.browser,
                details: "Unable to read cookies table.")
        }
        defer { sqlite3_finalize(statement) }

        let decryptor = LinuxChromiumDecryptor(databaseURL: databaseURL)
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

            let expires = LinuxChromiumDecryptor.date(fromChromiumTimestamp: expiresUtc)
            let sameSite = LinuxChromiumDecryptor.sameSite(from: sameSiteValue)

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

        if usedEncryptedValues, records.isEmpty, failedDecryptions > 0 {
            throw BrowserCookieError.loadFailed(
                browser: store.browser,
                details: "Unable to decrypt cookie values.")
        }

        return records
    }
}

private struct LinuxChromiumDecryptor {
    private static let salt = "saltysalt".data(using: .utf8) ?? Data()
    private static let iterations: Int = 1
    private static let keyLength: Int = 16

    let legacyKey: Data?
    let gcmKey: Data?

    init(databaseURL: URL) {
        let password = Self.safeStoragePassword()
        self.legacyKey = Self.deriveKey(from: password)
        self.gcmKey = Self.readLocalStateKey(databaseURL: databaseURL, legacyKey: self.legacyKey)
    }

    func decrypt(data: Data) -> String? {
        guard data.count > 3 else { return nil }
        let prefix = data.prefix(3)
        guard let prefixString = String(data: prefix, encoding: .utf8),
              prefixString == "v10" || prefixString == "v11" else {
            return nil
        }

        let payload = Data(data.dropFirst(3))
        if let gcmKey, let plaintext = Self.decryptGCM(payload: payload, key: gcmKey) {
            return plaintext
        }
        if let legacyKey, let plaintext = Self.decryptCBC(payload: payload, key: legacyKey) {
            return plaintext
        }
        return nil
    }

    private static func decryptCBC(payload: Data, key: Data) -> String? {
        let iv = Data(repeating: 0x20, count: 16)
        guard let data = CryptoSupport.decryptAESCBC(payload: payload, key: key, iv: iv) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decryptGCM(payload: Data, key: Data) -> String? {
        guard let data = CryptoSupport.decryptAESGCM(payload: payload, key: key) else { return nil }
        return String(decoding: data, as: UTF8.self)
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
            return .none
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

    private static func safeStoragePassword() -> String {
        if let env = ProcessInfo.processInfo.environment["SILO_CHROME_SAFE_STORAGE"], !env.isEmpty {
            return env
        }
        return "peanuts"
    }

    private static func deriveKey(from password: String) -> Data? {
        #if canImport(CryptoSwift)
        do {
            let key = try PKCS5.PBKDF2(
                password: Array(password.utf8),
                salt: Array(salt),
                iterations: iterations,
                keyLength: keyLength,
                variant: .sha1).calculate()
            return Data(key)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func readLocalStateKey(databaseURL: URL, legacyKey: Data?) -> Data? {
        guard let localStateURL = localStateURL(for: databaseURL),
              let data = try? Data(contentsOf: localStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let osCrypt = json["os_crypt"] as? [String: Any],
              let encryptedKeyBase64 = osCrypt["encrypted_key"] as? String,
              let encryptedKeyData = Data(base64Encoded: encryptedKeyBase64) else {
            return nil
        }

        var keyData = encryptedKeyData
        let dpapiPrefix = "DPAPI".data(using: .utf8) ?? Data()
        if keyData.starts(with: dpapiPrefix) {
            keyData = Data(keyData.dropFirst(dpapiPrefix.count))
        }

        if keyData.count == 32 {
            return keyData
        }

        if keyData.count >= 3,
           let prefix = String(data: keyData.prefix(3), encoding: .utf8),
           (prefix == "v10" || prefix == "v11"),
           let legacyKey,
           let decrypted = CryptoSupport.decryptAESCBC(
                payload: Data(keyData.dropFirst(3)),
                key: legacyKey,
                iv: Data(repeating: 0x20, count: 16)) {
            return decrypted.count == 32 ? decrypted : nil
        }

        return nil
    }

    private static func localStateURL(for databaseURL: URL) -> URL? {
        let parent = databaseURL.deletingLastPathComponent()
        let profileURL = parent.lastPathComponent == "Network" ? parent.deletingLastPathComponent() : parent
        let rootURL = profileURL.deletingLastPathComponent()
        let localStateURL = rootURL.appendingPathComponent("Local State")
        return FileManager.default.fileExists(atPath: localStateURL.path) ? localStateURL : nil
    }
}
#endif
