#if os(Linux)
import Foundation
import SQLite3

struct LinuxFirefoxCookieReader {
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

        let columns = Self.fetchColumns(db: db, table: "moz_cookies")
        let hostOnlyColumn = Self.hostOnlyColumn(in: columns)
        let selectColumns = Self.selectColumns(hostOnlyColumn: hostOnlyColumn)
        let query = "SELECT \(selectColumns) FROM moz_cookies"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw BrowserCookieError.loadFailed(
                browser: store.browser,
                details: "Unable to read cookies table.")
        }
        defer { sqlite3_finalize(statement) }

        let hostOnlyIndex = hostOnlyColumn == nil ? nil : 8
        var records: [BrowserCookieRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let host = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? ""
            let name = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? ""
            let path = sqlite3_column_text(statement, 2).flatMap { String(cString: $0) } ?? ""
            let value = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) } ?? ""
            let expirySeconds = sqlite3_column_int64(statement, 4)
            let isSecure = sqlite3_column_int(statement, 5) != 0
            let isHttpOnly = sqlite3_column_int(statement, 6) != 0
            let sameSiteValue = sqlite3_column_int(statement, 7)
            let isHostOnlyOverride: Bool?
            if hostOnlyColumn == "isHostOnly", let index = hostOnlyIndex {
                isHostOnlyOverride = sqlite3_column_int(statement, Int32(index)) != 0
            } else if hostOnlyColumn == "isDomain", let index = hostOnlyIndex {
                let isDomain = sqlite3_column_int(statement, Int32(index)) != 0
                isHostOnlyOverride = !isDomain
            } else {
                isHostOnlyOverride = nil
            }

            if host.isEmpty || name.isEmpty {
                continue
            }

            let expires = expirySeconds > 0 ? Date(timeIntervalSince1970: Double(expirySeconds)) : nil
            let sameSite = Self.sameSite(from: sameSiteValue)

            records.append(BrowserCookieRecord(
                domain: host,
                name: name,
                path: path.isEmpty ? "/" : path,
                value: value,
                expires: expires,
                isSecure: isSecure,
                isHTTPOnly: isHttpOnly,
                isHostOnly: isHostOnlyOverride,
                sameSite: sameSite))
        }

        return records
    }

    private static func sameSite(from value: Int32) -> BrowserCookieSameSite? {
        switch value {
        case 0:
            return .none
        case 1:
            return .lax
        case 2:
            return .strict
        default:
            return nil
        }
    }

    private static func fetchColumns(db: OpaquePointer?, table: String) -> Set<String> {
        guard let db else { return [] }
        var columns = Set<String>()
        let query = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let name = sqlite3_column_text(statement, 1) {
                    columns.insert(String(cString: name))
                }
            }
        }
        sqlite3_finalize(statement)
        return columns
    }

    private static func hostOnlyColumn(in columns: Set<String>) -> String? {
        if columns.contains("isHostOnly") {
            return "isHostOnly"
        }
        if columns.contains("isDomain") {
            return "isDomain"
        }
        return nil
    }

    private static func selectColumns(hostOnlyColumn: String?) -> String {
        var columns = [
            "host",
            "name",
            "path",
            "value",
            "expiry",
            "isSecure",
            "isHttpOnly",
            "sameSite",
        ]
        if let hostOnlyColumn {
            columns.append(hostOnlyColumn)
        }
        return columns.joined(separator: ", ")
    }
}
#endif
