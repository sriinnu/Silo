import Foundation
import SQLite3

/// Shared helpers for integration tests that build real cookie stores.
enum CookieTestFixtures {
    static func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    static func chromiumProfileLayout(in root: URL, useNetwork: Bool) -> (dbURL: URL, localStateURL: URL) {
        let profileURL = root.appendingPathComponent("Default")
        let cookiesURL: URL
        if useNetwork {
            cookiesURL = profileURL.appendingPathComponent("Network").appendingPathComponent("Cookies")
        } else {
            cookiesURL = profileURL.appendingPathComponent("Cookies")
        }
        let localStateURL = root.appendingPathComponent("Local State")
        return (cookiesURL, localStateURL)
    }

    static func writeLocalState(at url: URL, keyData: Data) throws {
        let json: [String: Any] = [
            "os_crypt": [
                "encrypted_key": keyData.base64EncodedString(),
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        try data.write(to: url)
    }

    static func createChromiumDatabase(
        at url: URL,
        domain: String = "example.com",
        name: String = "session",
        path: String = "/",
        value: String,
        encryptedValue: Data? = nil,
        expiresUtc: Int64 = 1_700_000_000 * 1_000_000,
        creationUtc: Int64? = nil,
        lastAccessUtc: Int64? = nil,
        priority: Int32? = nil,
        isSameParty: Bool? = nil,
        partitionKey: String? = nil,
        isSecure: Bool = true,
        isHTTPOnly: Bool = true,
        sameSite: Int32 = 1) throws
    {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw DatabaseError.openFailed
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE cookies (
            creation_utc INTEGER,
            host_key TEXT,
            name TEXT,
            path TEXT,
            value TEXT,
            encrypted_value BLOB,
            expires_utc INTEGER,
            last_access_utc INTEGER,
            is_secure INTEGER,
            is_httponly INTEGER,
            samesite INTEGER,
            priority INTEGER,
            is_same_party INTEGER,
            partition_key TEXT
        );
        """
        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.createFailed
        }

        try insertChromiumCookie(
            into: db,
            domain: domain,
            name: name,
            path: path,
            value: value,
            encryptedValue: encryptedValue,
            expiresUtc: expiresUtc,
            creationUtc: creationUtc,
            lastAccessUtc: lastAccessUtc,
            priority: priority,
            isSameParty: isSameParty,
            partitionKey: partitionKey,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            sameSite: sameSite)
    }

    static func insertChromiumCookie(
        into url: URL,
        domain: String = "example.com",
        name: String = "session",
        path: String = "/",
        value: String,
        encryptedValue: Data? = nil,
        expiresUtc: Int64 = 1_700_000_000 * 1_000_000,
        creationUtc: Int64? = nil,
        lastAccessUtc: Int64? = nil,
        priority: Int32? = nil,
        isSameParty: Bool? = nil,
        partitionKey: String? = nil,
        isSecure: Bool = true,
        isHTTPOnly: Bool = true,
        sameSite: Int32 = 1) throws
    {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw DatabaseError.openFailed
        }
        defer { sqlite3_close(db) }
        try insertChromiumCookie(
            into: db,
            domain: domain,
            name: name,
            path: path,
            value: value,
            encryptedValue: encryptedValue,
            expiresUtc: expiresUtc,
            creationUtc: creationUtc,
            lastAccessUtc: lastAccessUtc,
            priority: priority,
            isSameParty: isSameParty,
            partitionKey: partitionKey,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            sameSite: sameSite)
    }

    private static func insertChromiumCookie(
        into db: OpaquePointer?,
        domain: String,
        name: String,
        path: String,
        value: String,
        encryptedValue: Data?,
        expiresUtc: Int64,
        creationUtc: Int64?,
        lastAccessUtc: Int64?,
        priority: Int32?,
        isSameParty: Bool?,
        partitionKey: String?,
        isSecure: Bool,
        isHTTPOnly: Bool,
        sameSite: Int32) throws
    {
        guard let db else { throw DatabaseError.openFailed }
        let insertSQL = """
        INSERT INTO cookies (
            creation_utc, host_key, name, path, value, encrypted_value, expires_utc, last_access_utc,
            is_secure, is_httponly, samesite, priority, is_same_party, partition_key
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.insertFailed
        }
        defer { sqlite3_finalize(statement) }

        bindInt64(statement, index: 1, value: creationUtc)
        sqlite3_bind_text(statement, 2, domain, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, path, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, value, -1, sqliteTransient)
        if let encryptedValue {
            _ = encryptedValue.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 6, buffer.baseAddress, Int32(buffer.count), sqliteTransient)
            }
        } else {
            sqlite3_bind_blob(statement, 6, nil, 0, sqliteTransient)
        }
        sqlite3_bind_int64(statement, 7, expiresUtc)
        bindInt64(statement, index: 8, value: lastAccessUtc)
        sqlite3_bind_int(statement, 9, isSecure ? 1 : 0)
        sqlite3_bind_int(statement, 10, isHTTPOnly ? 1 : 0)
        sqlite3_bind_int(statement, 11, sameSite)
        bindInt(statement, index: 12, value: priority)
        bindInt(statement, index: 13, value: isSameParty.map { $0 ? 1 : 0 }.map(Int32.init))
        bindText(statement, index: 14, value: partitionKey)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.insertFailed
        }
    }

    static func createFirefoxDatabase(
        at url: URL,
        domain: String = "example.com",
        name: String = "pref",
        path: String = "/",
        value: String,
        expiry: Int64 = 1_700_000_000,
        creationTime: Int64? = nil,
        lastAccessed: Int64? = nil,
        priority: Int32? = nil,
        partitionKey: String? = nil,
        isSameParty: Bool? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: Int32 = 0,
        isHostOnly: Bool = true) throws
    {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw DatabaseError.openFailed
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE moz_cookies (
            host TEXT,
            name TEXT,
            path TEXT,
            value TEXT,
            expiry INTEGER,
            creationTime INTEGER,
            lastAccessed INTEGER,
            priority INTEGER,
            partitionKey TEXT,
            isSameParty INTEGER,
            isSecure INTEGER,
            isHttpOnly INTEGER,
            sameSite INTEGER,
            isHostOnly INTEGER
        );
        """
        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.createFailed
        }

        let insertSQL = """
        INSERT INTO moz_cookies (
            host, name, path, value, expiry, creationTime, lastAccessed, priority, partitionKey, isSameParty,
            isSecure, isHttpOnly, sameSite, isHostOnly
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.insertFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, domain, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, path, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, value, -1, sqliteTransient)
        sqlite3_bind_int64(statement, 5, expiry)
        bindInt64(statement, index: 6, value: creationTime)
        bindInt64(statement, index: 7, value: lastAccessed)
        bindInt(statement, index: 8, value: priority)
        bindText(statement, index: 9, value: partitionKey)
        bindInt(statement, index: 10, value: isSameParty.map { $0 ? 1 : 0 }.map(Int32.init))
        sqlite3_bind_int(statement, 11, isSecure ? 1 : 0)
        sqlite3_bind_int(statement, 12, isHTTPOnly ? 1 : 0)
        sqlite3_bind_int(statement, 13, sameSite)
        sqlite3_bind_int(statement, 14, isHostOnly ? 1 : 0)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.insertFailed
        }
    }

    static func makeSafariBinaryCookies(
        domain: String,
        name: String,
        path: String,
        value: String,
        expires: Date,
        createdAt: Date? = nil,
        isSecure: Bool,
        isHTTPOnly: Bool) -> Data
    {
        let flags: UInt32 = (isSecure ? 0x1 : 0) | (isHTTPOnly ? 0x4 : 0)
        let headerSize = 56
        let stringStart = headerSize
        var offsets: [UInt32] = []
        var stringData = Data()
        for component in [domain, name, path, value] {
            offsets.append(UInt32(stringStart + stringData.count))
            stringData.append(component.data(using: .utf8) ?? Data())
            stringData.append(0)
        }

        let recordSize = stringStart + stringData.count
        var record = Data(count: recordSize)
        writeUInt32LE(UInt32(recordSize), into: &record, at: 0)
        writeUInt32LE(0, into: &record, at: 4)
        writeUInt32LE(flags, into: &record, at: 8)
        writeUInt32LE(0, into: &record, at: 12) // hasPort
        writeUInt32LE(offsets[0], into: &record, at: 16)
        writeUInt32LE(offsets[1], into: &record, at: 20)
        writeUInt32LE(offsets[2], into: &record, at: 24)
        writeUInt32LE(offsets[3], into: &record, at: 28)
        writeUInt32LE(0, into: &record, at: 32) // comment
        writeUInt32LE(0, into: &record, at: 36) // comment URL
        writeDoubleLE(expires.timeIntervalSinceReferenceDate, into: &record, at: 40)
        let createdInterval = createdAt?.timeIntervalSinceReferenceDate ?? 0
        writeDoubleLE(createdInterval, into: &record, at: 48)

        record.replaceSubrange(stringStart..<(stringStart + stringData.count), with: stringData)

        let cookieOffset = 8 + 4 + 4
        let pageSize = cookieOffset + record.count
        var page = Data(count: pageSize)
        page.replaceSubrange(0..<4, with: UInt32(0x00000100).bigEndianBytes)
        writeUInt32LE(1, into: &page, at: 4)
        writeUInt32LE(UInt32(cookieOffset), into: &page, at: 8)
        writeUInt32LE(0, into: &page, at: 12)
        page.replaceSubrange(cookieOffset..<(cookieOffset + record.count), with: record)

        var file = Data()
        file.append("cook".data(using: .ascii) ?? Data())
        file.append(contentsOf: UInt32(1).bigEndianBytes)
        file.append(contentsOf: UInt32(page.count).bigEndianBytes)
        file.append(page)
        return file
    }

    private static func writeUInt32LE(_ value: UInt32, into data: inout Data, at offset: Int) {
        let bytes = value.littleEndianBytes
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }

    private static func writeDoubleLE(_ value: Double, into data: inout Data, at offset: Int) {
        let bits = value.bitPattern
        let bytes = bits.littleEndianBytes
        data.replaceSubrange(offset..<(offset + 8), with: bytes)
    }
}

private enum DatabaseError: Error {
    case openFailed
    case createFailed
    case insertFailed
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bindInt64(_ statement: OpaquePointer?, index: Int32, value: Int64?) {
    if let value {
        sqlite3_bind_int64(statement, index, value)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bindInt(_ statement: OpaquePointer?, index: Int32, value: Int32?) {
    if let value {
        sqlite3_bind_int(statement, index, value)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private func bindText(_ statement: OpaquePointer?, index: Int32, value: String?) {
    if let value {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    } else {
        sqlite3_bind_null(statement, index)
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian, Array.init)
    }

    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian, Array.init)
    }
}
