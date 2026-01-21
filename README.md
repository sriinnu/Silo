# Silo 🏺

**Cross-platform browser cookie storage extraction**

Silo is a Swift library for reading browser cookies across macOS, iOS, Linux, and Windows. Extract cookies from Safari, Chrome, Firefox, Edge, Brave, Arc, and more with a modern, type-safe API.

## ✨ Features

### Core Capabilities
- 🌍 **Multi-platform** – macOS, iOS, Linux, Windows with platform-specific optimizations
- 🌐 **Multi-browser** – Safari, Chrome, Firefox, Edge, Brave, Arc, Vivaldi, Helium, and more
- ⚡ **Swift 6** – Full concurrency support with async/await throughout
- 🔒 **Type-safe** – Strongly typed cookie operations with compile-time guarantees
- 👤 **Profile-aware** – Multiple browser profile support with automatic detection
- 🔍 **Query filtering** – Advanced domain matching, expiry handling, path filtering
- 🍪 **HTTPCookie** – Direct Foundation integration for seamless URLSession usage
- 📊 **Comprehensive** – Access to all cookie attributes (secure, httpOnly, sameSite, etc.)

### Advanced Features
Note: The advanced features below are planned and not yet implemented. See `TODO.md`.
- 🔄 **Cookie Manipulation** – Create, update, and delete cookies across browsers
- 📦 **Batch Operations** – Process multiple cookies efficiently with bulk APIs
- 💾 **Import/Export** – JSON and Netscape cookie format support
- 🔐 **Security** – Automatic keychain/DPAPI decryption for encrypted cookies
- 📈 **Analytics** – Cookie statistics, domain analysis, and expiry tracking
- 🔁 **Synchronization** – Copy cookies between browsers or profiles
- 🎯 **Smart Filtering** – Regex patterns, wildcard matching, attribute-based queries
- 🧪 **Testing Support** – Mock cookie stores for unit testing
- 📝 **Cookie Validation** – Detect invalid or problematic cookies
- 🔔 **Change Tracking** – Monitor cookie modifications and updates
- 🌐 **Session Management** – Extract and manage session cookies
- 🎨 **Customizable** – Extensible architecture for custom browser support

## Status
- Implemented: core models, query filtering, HTTPCookie mapping (host-only + SameSite), macOS store discovery + readers, Linux/Windows store discovery + readers (best-effort decryption).
- Planned: iOS reader, CRUD, import/export, sync, analytics, testing support.
- See `TODO.md` for the working backlog.
Note: On Linux/Windows, Silo reads Chromium/Firefox cookie stores with best-effort decryption; keyring integration is not included yet.

## 📦 Installation

```swift
dependencies: [
    .package(url: "https://github.com/sriinnu/Silo.git", from: "1.0.0")
]
```

## 🚀 Quick Start

```swift
import Silo

let client = BrowserCookieClient()

// List available profiles
let stores = client.stores(for: .chrome)

// Query cookies
let query = BrowserCookieQuery(
    domains: ["example.com"],
    domainMatch: .suffix
)

// Get records (grouped by store)
let sources = try client.records(matching: query, in: .chrome)
let records = sources.flatMap { $0.records }

// Convert to HTTPCookie
let cookies = try client.cookies(matching: query, in: .chrome)
```

## 🌍 Platform Support

| Browser | macOS | Linux | Windows | iOS |
|---------|-------|-------|---------|-----|
| Safari | read | - | - | planned |
| Chrome | read | read | read | - |
| Firefox | read | read | read | - |
| Edge | read | read | read | - |
| Brave | read | read | read | - |
| Arc | read | - | - | - |

Status legend: read = cookie reading implemented; discovery = profile/store detection only; planned = not implemented yet.

## 📝 API

### Query Filtering

```swift
// Exact match
let exactQuery = BrowserCookieQuery(
    domains: ["api.example.com"],
    domainMatch: .exact
)

// Multiple domains
let multiQuery = BrowserCookieQuery(
    domains: ["example.com", "example.org"],
    domainMatch: .suffix
)

// Include expired
let allQuery = BrowserCookieQuery(
    domains: ["example.com"],
    includeExpired: true
)
```

### Browser Selection

```swift
// Specific browser
let cookies = try client.cookies(matching: query, in: .chrome)

// Multiple browsers
let allCookies = try client.cookies(
    matching: query,
    in: [.chrome, .firefox, .safari]
)
```

## 🔐 Permissions

### macOS
- **Full Disk Access** for Safari
- **Keychain** for Chromium encrypted cookies

### Linux
- **Keyring access** for encrypted cookies
- **File permissions** for profiles

### Windows
- **DPAPI** for encrypted cookies

### iOS
- **Keychain** access
- **Shared container** entitlements

## Testing

```bash
swift test
```

## 📚 Documentation

```bash
swift package generate-documentation --target Silo
```

## 📄 License

MIT License - Copyright (c) 2026 Srinivas Pendela

---

**GitHub:** https://github.com/sriinnu/Silo  
**Author:** Srinivas Pendela (hello@srinivas.dev)

## Advanced Usage
Note: Examples below reflect planned APIs; not all types or operations are implemented yet.

### Cookie Manipulation (planned)

```swift
import Silo

let client = BrowserCookieClient()

// Update cookie value
var cookie = try client.cookie(named: "session_id", domain: "example.com", in: .chrome)
cookie.value = "new_session_value"
try client.update(cookie, in: .chrome)

// Delete specific cookie
try client.delete(cookie, in: .chrome)

// Delete all cookies for domain
try client.deleteCookies(forDomain: "example.com", in: .chrome)

// Create new cookie
let newCookie = BrowserCookie(
    name: "user_pref",
    value: "dark_mode",
    domain: "example.com",
    path: "/",
    expires: Date().addingTimeInterval(86400 * 365), // 1 year
    isSecure: true,
    isHTTPOnly: false,
    sameSite: .lax
)
try client.insert(newCookie, in: .chrome)
```

### Batch Operations (planned)

```swift
// Export all cookies to JSON
let allSources = try client.records(matching: BrowserCookieQuery(), in: .chrome)
let allCookies = allSources.flatMap { $0.records }
let jsonData = try JSONEncoder().encode(allCookies)
try jsonData.write(to: URL(fileURLWithPath: "cookies.json"))

// Import cookies from JSON
let importedData = try Data(contentsOf: URL(fileURLWithPath: "cookies.json"))
let cookies = try JSONDecoder().decode([BrowserCookieRecord].self, from: importedData)
for cookie in cookies {
    try client.insert(cookie.httpCookie, in: .chrome)
}

// Copy cookies between browsers
let firefoxCookies = try client.cookies(matching: BrowserCookieQuery(), in: .firefox)
for cookie in firefoxCookies {
    try client.insert(cookie, in: .chrome)
}

// Bulk delete with filter
let query = BrowserCookieQuery(
    domains: ["ads.example.com", "tracker.example.com"],
    domainMatch: .exact
)
try client.deleteCookies(matching: query, in: .chrome)
```

### Netscape Cookie Format (planned)

```swift
// Export to Netscape format (wget/curl compatible)
let cookies = try client.cookies(matching: BrowserCookieQuery(), in: .chrome)
let netscapeFormat = cookies.map { cookie in
    let secure = cookie.isSecure ? "TRUE" : "FALSE"
    let httpOnly = cookie.isHTTPOnly ? "#HttpOnly_" : ""
    let expires = Int(cookie.expiresDate?.timeIntervalSince1970 ?? 0)
    return "\(httpOnly)\(cookie.domain)\tTRUE\t\(cookie.path)\t\(secure)\t\(expires)\t\(cookie.name)\t\(cookie.value)"
}.joined(separator: "\n")

try netscapeFormat.write(toFile: "cookies.txt", atomically: true, encoding: .utf8)

// Import from Netscape format
let netscapeContent = try String(contentsOfFile: "cookies.txt")
for line in netscapeContent.components(separatedBy: .newlines) {
    guard !line.isEmpty, !line.hasPrefix("#") else { continue }
    let parts = line.components(separatedBy: "\t")
    // Parse and insert cookie
}
```

### Cookie Analytics (planned)

```swift
struct CookieAnalyzer {
    let client: BrowserCookieClient
    
    func analyzeChrome() throws -> CookieStatistics {
        let sources = try client.records(matching: BrowserCookieQuery(), in: .chrome)
        let cookies = sources.flatMap { $0.records }
        
        return CookieStatistics(
            totalCount: cookies.count,
            secureCount: cookies.filter { $0.isSecure }.count,
            httpOnlyCount: cookies.filter { $0.isHTTPOnly }.count,
            sessionCount: cookies.filter { $0.isSession }.count,
            expiredCount: cookies.filter { 
                guard let expires = $0.expires else { return false }
                return expires < Date()
            }.count,
            domainDistribution: Dictionary(grouping: cookies, by: \.domain)
                .mapValues { $0.count },
            sameSiteDistribution: Dictionary(grouping: cookies, by: \.sameSite)
                .mapValues { $0.count }
        )
    }
    
    func findLargeCookies(minimumBytes: Int = 4000) throws -> [BrowserCookieRecord] {
        let sources = try client.records(matching: BrowserCookieQuery(), in: .chrome)
        let cookies = sources.flatMap { $0.records }
        return cookies.filter { $0.value.utf8.count >= minimumBytes }
    }
    
    func findExpiringSoon(days: Int = 7) throws -> [BrowserCookieRecord] {
        let threshold = Date().addingTimeInterval(Double(days) * 86400)
        let sources = try client.records(matching: BrowserCookieQuery(), in: .chrome)
        let cookies = sources.flatMap { $0.records }
        return cookies.filter { cookie in
            guard let expires = cookie.expires else { return false }
            return expires < threshold && expires > Date()
        }
    }
}

struct CookieStatistics {
    let totalCount: Int
    let secureCount: Int
    let httpOnlyCount: Int
    let sessionCount: Int
    let expiredCount: Int
    let domainDistribution: [String: Int]
    let sameSiteDistribution: [BrowserCookieSameSite: Int]
}
```

### Cookie Synchronization (planned)

```swift
struct CookieSyncManager {
    let client: BrowserCookieClient
    
    func syncBrowsers(from source: Browser, to destination: Browser, domains: [String]) async throws {
        let query = BrowserCookieQuery(domains: domains, domainMatch: .suffix)
        let cookies = try client.cookies(matching: query, in: source)
        
        print("Syncing \(cookies.count) cookies from \(source) to \(destination)...")
        
        for cookie in cookies {
            try client.insert(cookie, in: destination)
        }
        
        print("✓ Sync complete")
    }
    
    func backupCookies(browser: Browser, to path: String) throws {
        let sources = try client.records(matching: BrowserCookieQuery(), in: browser)
        let cookies = sources.flatMap { $0.records }
        let backup = CookieBackup(
            browser: browser,
            timestamp: Date(),
            cookies: cookies
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(backup)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    func restoreCookies(from path: String, to browser: Browser) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup = try decoder.decode(CookieBackup.self, from: data)
        
        for cookie in backup.cookies {
            try client.insert(cookie.httpCookie, in: browser)
        }
    }
}

struct CookieBackup: Codable {
    let browser: Browser
    let timestamp: Date
    let cookies: [BrowserCookieRecord]
}
```

### Advanced Filtering (planned)

```swift
// Regex domain matching
let regexQuery = BrowserCookieQuery(
    domainPattern: #".*\.(google|youtube)\.com$"#,
    useRegex: true
)

// Path filtering
let pathQuery = BrowserCookieQuery(
    domains: ["example.com"],
    paths: ["/api", "/admin"],
    pathMatch: .prefix
)

// Attribute-based filtering
let secureQuery = BrowserCookieQuery(
    secureOnly: true,
    httpOnlyOnly: true,
    excludeSession: true
)

// Combined filtering
let complexQuery = BrowserCookieQuery(
    domains: ["example.com", "api.example.com"],
    domainMatch: .exact,
    paths: ["/"],
    secureOnly: true,
    minExpiryDate: Date().addingTimeInterval(86400 * 30), // 30 days from now
    sameSite: .strict
)

let filteredCookies = try client.cookies(matching: complexQuery, in: .chrome)
```

### Session Management (planned)

```swift
struct SessionManager {
    let client: BrowserCookieClient
    
    func extractSession(for domain: String, from browser: Browser) throws -> Session {
        let query = BrowserCookieQuery(domains: [domain], domainMatch: .suffix)
        let cookies = try client.cookies(matching: query, in: browser)
        
        return Session(
            domain: domain,
            cookies: cookies,
            extractedAt: Date()
        )
    }
    
    func injectSession(_ session: Session, into urlSession: URLSession) {
        let storage = HTTPCookieStorage.shared
        for cookie in session.cookies {
            storage.setCookie(cookie)
        }
    }
    
    func validateSession(_ session: Session) -> ValidationResult {
        var issues: [String] = []
        
        // Check for expired cookies
        let expiredCount = session.cookies.filter { cookie in
            guard let expiresDate = cookie.expiresDate else { return false }
            return expiresDate < Date()
        }.count
        
        if expiredCount > 0 {
            issues.append("\(expiredCount) expired cookies")
        }
        
        // Check for missing critical cookies
        let hasSessions = session.cookies.contains { $0.name.contains("session") }
        if !hasSessions {
            issues.append("No session cookies found")
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
}

struct Session {
    let domain: String
    let cookies: [HTTPCookie]
    let extractedAt: Date
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
}
```

### Testing Support (planned)

```swift
import XCTest
@testable import Silo

class CookieTests: XCTestCase {
    var mockClient: MockBrowserCookieClient!
    
    override func setUp() {
        super.setUp()
        mockClient = MockBrowserCookieClient()
    }
    
    func testCookieExtraction() throws {
        // Arrange
        let mockCookie = BrowserCookie(
            name: "test",
            value: "value",
            domain: "example.com",
            path: "/",
            expires: Date().addingTimeInterval(3600),
            isSecure: true,
            isHTTPOnly: true,
            sameSite: .lax
        )
        mockClient.mockCookies = [mockCookie]
        
        // Act
        let query = BrowserCookieQuery(domains: ["example.com"])
        let cookies = try mockClient.cookies(matching: query, in: .chrome)
        
        // Assert
        XCTAssertEqual(cookies.count, 1)
        XCTAssertEqual(cookies.first?.name, "test")
    }
}

class MockBrowserCookieClient: BrowserCookieClient {
    var mockCookies: [BrowserCookie] = []
    
    override func cookies(matching query: BrowserCookieQuery, in browser: Browser) throws -> [HTTPCookie] {
        return mockCookies.map { $0.httpCookie }
    }
}
```

## 🎯 Use Cases

### Web Automation & Testing
- Extract authentication cookies for automated testing
- Transfer sessions between test environments
- Validate cookie security attributes
- Test cookie-based features across browsers

### Development Tools
- Debug cookie issues in web applications
- Inspect third-party cookie behavior
- Analyze cookie storage patterns
- Build browser cookie inspectors

### Security & Privacy
- Audit cookie security settings
- Detect tracking cookies
- Backup/restore cookie data
- Analyze cookie compliance (GDPR, etc.)

### Data Migration
- Transfer browser profiles
- Clone development environments
- Sync authentication across machines
- Import/export cookie databases

### Analytics & Monitoring
- Track cookie usage patterns
- Monitor cookie expiry
- Analyze storage efficiency
- Generate cookie reports

## 🔐 Security Considerations

### macOS Keychain Access
On macOS, Chrome and other Chromium browsers encrypt cookie values using the system keychain. Silo automatically handles decryption, but your app needs:

```swift
// No special entitlements needed - Silo handles keychain access
// Just ensure your app has necessary file permissions
```

### Cookie Value Encryption
Never log or expose cookie values in plain text:

```swift
// ❌ Bad
print("Cookie: \(cookie.value)")

// ✅ Good
let masked = String(cookie.value.prefix(4)) + "..."
print("Cookie: \(masked)")
```

### Secure Storage
When exporting cookies, use encrypted storage:

```swift
import CryptoKit

func exportCookiesSecurely(cookies: [HTTPCookie], password: String) throws -> Data {
    let encoder = JSONEncoder()
    let data = try encoder.encode(cookies)
    
    // Encrypt with password-based key
    let salt = Data("YourAppSalt".utf8)
    let key = SymmetricKey(data: SHA256.hash(data: password.data(using: .utf8)! + salt))
    let sealedBox = try AES.GCM.seal(data, using: key)
    
    return sealedBox.combined!
}
```

## 📚 API Reference
Note: CRUD, import/export, sync, and analytics APIs are planned but not implemented yet. See `TODO.md`.

### BrowserCookieClient

```swift
public struct BrowserCookieClient {
    // Initialize
    public init(configuration: Configuration = Configuration())

    // Browser stores
    public func stores(for browser: Browser) -> [BrowserCookieStore]
    public func stores(in browsers: [Browser]) -> [BrowserCookieStore]

    // Query cookies
    public func records(matching query: BrowserCookieQuery, in store: BrowserCookieStore) throws -> [BrowserCookieRecord]
    public func records(matching query: BrowserCookieQuery, in browser: Browser) throws -> [BrowserCookieStoreRecords]
    public func records(matching query: BrowserCookieQuery, in browsers: [Browser]) throws -> [BrowserCookieStoreRecords]

    public func cookies(matching query: BrowserCookieQuery, in store: BrowserCookieStore) throws -> [HTTPCookie]
    public func cookies(matching query: BrowserCookieQuery, in browser: Browser) throws -> [HTTPCookie]
    public func cookies(matching query: BrowserCookieQuery, in browsers: [Browser]) throws -> [HTTPCookie]
}
```

### BrowserCookieQuery

```swift
public struct BrowserCookieQuery {
    public var domains: [String]
    public var domainMatch: BrowserCookieDomainMatch
    public var domainPattern: String?
    public var useRegex: Bool
    public var paths: [String]
    public var pathMatch: BrowserCookiePathMatch
    public var secureOnly: Bool?
    public var httpOnlyOnly: Bool?
    public var excludeSession: Bool
    public var minExpiryDate: Date?
    public var maxExpiryDate: Date?
    public var sameSite: BrowserCookieSameSite?
    public var origin: BrowserCookieOriginStrategy
    public var includeExpired: Bool
    public var referenceDate: Date
}
```

## See Also

[Helix](https://github.com/sriinnu/Helix) – Command-line parsing framework
