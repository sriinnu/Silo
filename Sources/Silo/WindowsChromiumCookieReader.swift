#if os(Windows)
import Foundation
import SQLite3
import WinSDK

struct WindowsChromiumCookieReader {
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

        let decryptor = WindowsChromiumDecryptor(databaseURL: databaseURL)
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

            let expires = WindowsChromiumDecryptor.date(fromChromiumTimestamp: expiresUtc)
            let sameSite = WindowsChromiumDecryptor.sameSite(from: sameSiteValue)

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

private struct WindowsChromiumDecryptor {
    let masterKey: Data?

    init(databaseURL: URL) {
        self.masterKey = Self.readLocalStateKey(databaseURL: databaseURL)
    }

    func decrypt(data: Data) -> String? {
        guard data.count > 3 else { return nil }
        let prefix = data.prefix(3)
        if let prefixString = String(data: prefix, encoding: .utf8),
           prefixString == "v10" || prefixString == "v11" {
            guard let masterKey else { return nil }
            let payload = Data(data.dropFirst(3))
            guard let plaintext = CryptoSupport.decryptAESGCM(payload: payload, key: masterKey) else { return nil }
            return String(decoding: plaintext, as: UTF8.self)
        }

        if let plaintext = Self.decryptDPAPI(data: data) {
            return String(decoding: plaintext, as: UTF8.self)
        }

        return nil
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

    private static func readLocalStateKey(databaseURL: URL) -> Data? {
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

        guard let decrypted = decryptDPAPI(data: keyData) else { return nil }
        return decrypted.count == 32 ? decrypted : nil
    }

    private static func localStateURL(for databaseURL: URL) -> URL? {
        let parent = databaseURL.deletingLastPathComponent()
        let profileURL = parent.lastPathComponent == "Network" ? parent.deletingLastPathComponent() : parent
        let rootURL = profileURL.deletingLastPathComponent()
        let localStateURL = rootURL.appendingPathComponent("Local State")
        return FileManager.default.fileExists(atPath: localStateURL.path) ? localStateURL : nil
    }

    private static func decryptDPAPI(data: Data) -> Data? {
        var input = DATA_BLOB()
        var output = DATA_BLOB()
        let copied = [UInt8](data)

        return copied.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return nil }
            input.pbData = UnsafeMutablePointer<UInt8>(mutating: baseAddress.assumingMemoryBound(to: UInt8.self))
            input.cbData = UInt32(buffer.count)
            let result = CryptUnprotectData(&input, nil, nil, nil, nil, 0, &output)
            guard result != 0, let outData = output.pbData else {
                return nil
            }
            let decrypted = Data(bytes: outData, count: Int(output.cbData))
            LocalFree(UnsafeMutableRawPointer(outData))
            return decrypted
        }
    }
}
#endif
