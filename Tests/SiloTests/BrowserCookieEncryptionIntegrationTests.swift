import Foundation
import XCTest
@testable import Silo

#if canImport(CryptoSwift)
import CryptoSwift
#endif

#if os(Linux)
import Glibc
#endif

#if os(Windows)
import WinSDK
#endif

final class BrowserCookieEncryptionIntegrationTests: XCTestCase {
    func testChromiumDecryptsAESGCMWithLocalStateKey() throws {
        #if os(Windows)
        throw XCTSkip("Windows uses DPAPI-wrapped Local State keys; covered by Windows-specific test.")
        #endif
        #if !canImport(CryptoSwift)
        throw XCTSkip("CryptoSwift required for AES-GCM test.")
        #endif

        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let layout = CookieTestFixtures.chromiumProfileLayout(in: tempDir, useNetwork: true)
        let key = Data(repeating: 0x11, count: 32)
        try CookieTestFixtures.writeLocalState(at: layout.localStateURL, keyData: key)

        let nonce = Data(repeating: 0x22, count: 12)
        let plaintext = Data("gcm-secret".utf8)
        let encrypted = try encryptAESGCM(plaintext: plaintext, key: key, nonce: nonce)
        let payload = nonce + encrypted
        let encryptedValue = Data("v10".utf8) + payload

        try CookieTestFixtures.createChromiumDatabase(
            at: layout.dbURL,
            value: "",
            encryptedValue: encryptedValue,
            isSecure: true,
            isHTTPOnly: true,
            sameSite: 1)

        let store = BrowserCookieStore(
            browser: .chrome,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .network,
            label: "Default",
            databaseURL: layout.dbURL)

        #if os(macOS)
        let reader = MacOSChromiumCookieReader()
        #elseif os(Linux)
        let reader = LinuxChromiumCookieReader()
        #else
        let reader = MacOSChromiumCookieReader()
        #endif

        let records = try reader.readCookies(store: store)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.value, "gcm-secret")
    }

    #if os(Linux)
    func testChromiumDecryptsCBCWithPeanuts() throws {
        #if !canImport(CryptoSwift)
        throw XCTSkip("CryptoSwift required for AES-CBC test.")
        #endif
        setenv("SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK", "1", 1)
        defer { unsetenv("SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK") }
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let layout = CookieTestFixtures.chromiumProfileLayout(in: tempDir, useNetwork: false)
        let key = try derivePeanutsKey()
        let iv = Data(repeating: 0x20, count: 16)
        let plaintext = Data("cbc-secret".utf8)
        let encrypted = try encryptAESCBC(plaintext: plaintext, key: key, iv: iv)
        let encryptedValue = Data("v10".utf8) + encrypted

        try CookieTestFixtures.createChromiumDatabase(
            at: layout.dbURL,
            value: "",
            encryptedValue: encryptedValue,
            isSecure: false,
            isHTTPOnly: false,
            sameSite: 0)

        let store = BrowserCookieStore(
            browser: .chromium,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .primary,
            label: "Default",
            databaseURL: layout.dbURL)

        let reader = LinuxChromiumCookieReader()
        let records = try reader.readCookies(store: store)
        XCTAssertEqual(records.first?.value, "cbc-secret")
    }
    #endif

    #if os(Windows)
    func testChromiumDecryptsDPAPIWrappedKey() throws {
        #if !canImport(CryptoSwift)
        throw XCTSkip("CryptoSwift required for AES-GCM test.")
        #endif
        let tempDir = try CookieTestFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let layout = CookieTestFixtures.chromiumProfileLayout(in: tempDir, useNetwork: true)
        let masterKey = Data(repeating: 0x33, count: 32)
        guard let encryptedKey = encryptDPAPI(data: masterKey) else {
            throw XCTSkip("DPAPI not available in this environment.")
        }
        let keyData = Data("DPAPI".utf8) + encryptedKey
        try CookieTestFixtures.writeLocalState(at: layout.localStateURL, keyData: keyData)

        let nonce = Data(repeating: 0x44, count: 12)
        let plaintext = Data("win-secret".utf8)
        let encrypted = try encryptAESGCM(plaintext: plaintext, key: masterKey, nonce: nonce)
        let payload = nonce + encrypted
        let encryptedValue = Data("v10".utf8) + payload

        try CookieTestFixtures.createChromiumDatabase(
            at: layout.dbURL,
            value: "",
            encryptedValue: encryptedValue,
            isSecure: true,
            isHTTPOnly: true,
            sameSite: 1)

        let store = BrowserCookieStore(
            browser: .chrome,
            profile: BrowserProfile(id: "Default", name: "Default"),
            kind: .network,
            label: "Default",
            databaseURL: layout.dbURL)

        let reader = WindowsChromiumCookieReader()
        let records = try reader.readCookies(store: store)
        XCTAssertEqual(records.first?.value, "win-secret")
    }
    #endif

    private func encryptAESGCM(plaintext: Data, key: Data, nonce: Data) throws -> Data {
        #if canImport(CryptoSwift)
        let gcm = GCM(iv: Array(nonce), mode: .combined)
        let aes = try AES(key: Array(key), blockMode: gcm, padding: .noPadding)
        let encrypted = try aes.encrypt(Array(plaintext))
        return Data(encrypted)
        #else
        throw NSError(domain: "CryptoSwiftMissing", code: 1)
        #endif
    }

    #if os(Linux)
    private func encryptAESCBC(plaintext: Data, key: Data, iv: Data) throws -> Data {
        #if canImport(CryptoSwift)
        let aes = try AES(key: Array(key), blockMode: CBC(iv: Array(iv)), padding: .pkcs7)
        return Data(try aes.encrypt(Array(plaintext)))
        #else
        throw NSError(domain: "CryptoSwiftMissing", code: 1)
        #endif
    }

    private func derivePeanutsKey() throws -> Data {
        #if canImport(CryptoSwift)
        let key = try PKCS5.PBKDF2(
            password: Array("peanuts".utf8),
            salt: Array("saltysalt".utf8),
            iterations: 1,
            keyLength: 16,
            variant: .sha1).calculate()
        return Data(key)
        #else
        throw NSError(domain: "CryptoSwiftMissing", code: 1)
        #endif
    }
    #endif

    #if os(Windows)
    private func encryptDPAPI(data: Data) -> Data? {
        var input = DATA_BLOB()
        var output = DATA_BLOB()
        let copied = [UInt8](data)
        let result = copied.withUnsafeBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress else { return false }
            input.pbData = UnsafeMutablePointer<UInt8>(mutating: baseAddress.assumingMemoryBound(to: UInt8.self))
            input.cbData = UInt32(buffer.count)
            return CryptProtectData(&input, nil, nil, nil, nil, 0, &output) != 0
        }
        guard result, let outData = output.pbData else {
            return nil
        }
        let encrypted = Data(bytes: outData, count: Int(output.cbData))
        LocalFree(UnsafeMutableRawPointer(outData))
        return encrypted
    }
    #endif
}
