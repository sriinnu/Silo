#if os(macOS)
import CommonCrypto
import Foundation
import Security
import SQLite3

struct MacOSChromiumCookieReader {
    func readCookies(store: BrowserCookieStore) throws -> [BrowserCookieRecord] {
        guard let databaseURL = store.databaseURL else {
            throw BrowserCookieError.notFound(
                browser: store.browser,
                details: "Missing cookie database URL.")
        }

        let (cookieValues, usedEncryptedValues) = try readCookieRows(databaseURL: databaseURL, browser: store.browser)
        if usedEncryptedValues, !cookieValues.hasDecryptionKey {
            throw BrowserCookieError.accessDenied(
                browser: store.browser,
                details: "Keychain access required to decrypt cookies.")
        }
        return cookieValues.records
    }

    private func readCookieRows(databaseURL: URL, browser: Browser) throws -> (CookieReadResult, Bool) {
        let fm = FileManager.default
        let tempURL = fm.temporaryDirectory
            .appendingPathComponent("silo", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
        var readURL = databaseURL
        let tempParent = tempURL.deletingLastPathComponent()
        try? fm.createDirectory(at: tempParent, withIntermediateDirectories: true)
        do {
            try fm.copyItem(at: databaseURL, to: tempURL)
            readURL = tempURL
        } catch {
            readURL = databaseURL
        }
        defer { try? fm.removeItem(at: tempURL) }

        var db: OpaquePointer?
        if sqlite3_open_v2(readURL.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
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

        let decryptor = ChromiumCookieDecryptor(browser: browser)
        var records: [BrowserCookieRecord] = []
        var usedEncryptedValues = false

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
                decryptedValue = (try? decryptor.decrypt(data: data)) ?? ""
            } else {
                decryptedValue = value
            }

            if decryptedValue.isEmpty || hostKey.isEmpty || name.isEmpty {
                continue
            }

            let expires = ChromiumCookieDecryptor.date(fromChromiumTimestamp: expiresUtc)
            let sameSite = ChromiumCookieDecryptor.sameSite(from: sameSiteValue)

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

        return (CookieReadResult(records: records, hasDecryptionKey: decryptor.hasKey), usedEncryptedValues)
    }
}

private struct CookieReadResult {
    let records: [BrowserCookieRecord]
    let hasDecryptionKey: Bool
}

private struct ChromiumCookieDecryptor {
    private static let salt = "saltysalt".data(using: .utf8) ?? Data()
    private static let iterations: UInt32 = 1003
    private static let keyLength = kCCKeySizeAES128
    private static let chromiumEpoch: Date = {
        var components = DateComponents()
        components.year = 1601
        components.month = 1
        components.day = 1
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }()

    let key: Data?

    var hasKey: Bool { self.key != nil }

    init(browser: Browser) {
        guard let serviceName = Self.serviceName(for: browser) else {
            self.key = nil
            return
        }
        guard let password = Self.readKeychainPassword(service: serviceName) else {
            self.key = nil
            return
        }
        self.key = Self.deriveKey(from: password)
    }

    func decrypt(data: Data) throws -> String {
        guard let key else { return "" }
        guard data.count > 3 else { return "" }
        let prefix = data.prefix(3)
        guard let prefixString = String(data: prefix, encoding: .utf8),
              prefixString == "v10" || prefixString == "v11" else {
            return ""
        }

        let ciphertext = Data(data.dropFirst(3))
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)

        var outLength: size_t = 0
        var outData = Data(count: ciphertext.count + kCCBlockSizeAES128)
        let status = outData.withUnsafeMutableBytes { outBytes in
            ciphertext.withUnsafeBytes { cipherBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            cipherBytes.baseAddress,
                            ciphertext.count,
                            outBytes.baseAddress,
                            outData.count,
                            &outLength)
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            return ""
        }
        outData.removeSubrange(outLength..<outData.count)
        return String(data: outData, encoding: .utf8) ?? ""
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

    private static func deriveKey(from password: String) -> Data? {
        let passwordBytes = Array(password.utf8)
        var key = Data(count: keyLength)
        let status = key.withUnsafeMutableBytes { keyBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes,
                passwordBytes.count,
                [UInt8](salt),
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                iterations,
                keyBytes.bindMemory(to: UInt8.self).baseAddress,
                keyLength)
        }
        return status == kCCSuccess ? key : nil
    }

    private static func readKeychainPassword(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func serviceName(for browser: Browser) -> String? {
        switch browser {
        case .chrome: return "Chrome Safe Storage"
        case .chromeBeta: return "Chrome Beta Safe Storage"
        case .chromeCanary: return "Chrome Canary Safe Storage"
        case .chromium: return "Chromium Safe Storage"
        case .brave: return "Brave Safe Storage"
        case .braveBeta: return "Brave Browser Beta Safe Storage"
        case .braveNightly: return "Brave Browser Nightly Safe Storage"
        case .edge: return "Microsoft Edge Safe Storage"
        case .edgeBeta: return "Microsoft Edge Beta Safe Storage"
        case .edgeCanary: return "Microsoft Edge Canary Safe Storage"
        case .arc: return "Arc Safe Storage"
        case .arcBeta: return "Arc Beta Safe Storage"
        case .arcCanary: return "Arc Canary Safe Storage"
        case .vivaldi: return "Vivaldi Safe Storage"
        case .helium: return "Helium Safe Storage"
        case .chatgptAtlas: return "ChatGPT Atlas Safe Storage"
        case .safari, .firefox:
            return nil
        }
    }
}
#endif
