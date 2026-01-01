import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// High-level API for enumerating and reading browser cookies.
public struct BrowserCookieClient: Sendable {
    public struct Configuration: Sendable {
        public var homeDirectories: [URL]

        public init(homeDirectories: [URL] = Self.defaultHomeDirectories()) {
            self.homeDirectories = homeDirectories
        }

        public static func defaultHomeDirectories() -> [URL] {
            var dirs: [URL] = []
            #if os(macOS) || os(iOS)
            dirs.append(FileManager.default.homeDirectoryForCurrentUser)
            #elseif os(Linux) || os(Windows)
            if let home = ProcessInfo.processInfo.environment["HOME"] {
                dirs.append(URL(fileURLWithPath: home))
            }
            #endif
            return dirs
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Returns cookie stores for a specific browser.
    public func stores(for browser: Browser) -> [BrowserCookieStore] {
        []  // Placeholder - would scan for profiles
    }

    /// Returns cookie stores for multiple browsers.
    public func stores(in browsers: [Browser]) -> [BrowserCookieStore] {
        browsers.flatMap { self.stores(for: $0) }
    }

    /// Loads cookie records from multiple browsers.
    public func records(
        matching query: BrowserCookieQuery,
        in browsers: [Browser]) throws -> [BrowserCookieStoreRecords]
    {
        try browsers.flatMap { try self.records(matching: query, in: $0) }
    }

    /// Loads cookie records from a specific browser.
    public func records(
        matching query: BrowserCookieQuery,
        in browser: Browser) throws -> [BrowserCookieStoreRecords]
    {
        let stores = self.stores(for: browser)
        return try stores.compactMap { store in
            let records = try self.records(matching: query, in: store)
            guard !records.isEmpty else { return nil }
            return BrowserCookieStoreRecords(store: store, records: records)
        }
    }

    /// Loads cookie records from a specific cookie store.
    public func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore) throws -> [BrowserCookieRecord]
    {
        // Placeholder - would actually read cookies
        return []
    }

    /// Loads HTTPCookie values from a specific store.
    public func cookies(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore) throws -> [HTTPCookie]
    {
        let records = try self.records(matching: query, in: store)
        return Self.makeHTTPCookies(records, origin: query.origin)
    }

    /// Loads HTTPCookie values from multiple browser stores.
    public func cookies(
        matching query: BrowserCookieQuery,
        in browser: Browser) throws -> [HTTPCookie]
    {
        let sources = try self.records(matching: query, in: browser)
        return sources.flatMap { $0.cookies(origin: query.origin) }
    }

    /// Loads HTTPCookie values from multiple browsers.
    public func cookies(
        matching query: BrowserCookieQuery,
        in browsers: [Browser]) throws -> [HTTPCookie]
    {
        let sources = try self.records(matching: query, in: browsers)
        return sources.flatMap { $0.cookies(origin: query.origin) }
    }

    /// Convert cookie records into HTTPCookie values.
    public static func makeHTTPCookies(
        _ records: [BrowserCookieRecord],
        origin: BrowserCookieOriginStrategy = .domainBased) -> [HTTPCookie]
    {
        records.compactMap { record in
            let domain = normalizeDomain(record.domain)
            guard !domain.isEmpty else { return nil }
            var props: [HTTPCookiePropertyKey: Any] = [
                .domain: domain,
                .name: record.name,
                .path: record.path,
                .value: record.value,
            ]
            if record.isSecure {
                props[.secure] = "TRUE"
            }
            if let expires = record.expires {
                props[.expires] = expires
            }
            if let originURL = origin.resolve(domain: domain) {
                props[.originURL] = originURL
            }
            return HTTPCookie(properties: props)
        }
    }

    private static func normalizeDomain(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
    }
}
