# Silo 🏺

**Cross-platform browser cookie storage extraction**

Silo is a Swift library for reading browser cookies across macOS, iOS, Linux, and Windows. Extract cookies from Safari, Chrome, Firefox, Edge, Brave, Arc, and more with a modern, type-safe API.

## ✨ Features

### Core Capabilities
- 🌍 **Multi-platform** – macOS, Linux, Windows, iOS (app container only)
- 🌐 **Multi-browser** – Safari, Chrome, Firefox, Edge, Brave, Arc, Vivaldi, Helium, and more
- 👤 **Profile-aware** – Multiple browser profile support with automatic detection
- 🔍 **Query filtering** – Domain/path/expiry/flag filtering with regex support
- 🔐 **Decryption** – macOS Keychain + Local State, Windows DPAPI, Linux Secret Service + "peanuts" fallback
- 🧯 **Decryption policy** – Best-effort or strict failure behavior
- 🧹 **Redaction** – Safe logging via `BrowserCookieRecord.redactedValue`
- 🍪 **HTTPCookie** – Direct Foundation integration for seamless URLSession usage
- 📊 **Comprehensive** – Access to all cookie attributes (secure, httpOnly, sameSite, etc.)

## Status
- Implemented: core models, query filtering, HTTPCookie mapping (host-only + SameSite), macOS/Linux/Windows readers, iOS app-container reader, Linux Secret Service lookup (fallback to peanuts).
- Planned: deeper keyring integration and iOS entitlement guidance.
- See `TODO.md` for the working backlog.
Note: Linux decryption uses Secret Service when available and falls back to the "peanuts" key. iOS reads app-container cookies only.

## Roadmap
- iOS entitlements and shared container guidance
- Linux keyring/libsecret hardening
- CRUD operations and JSON import/export
- Sync/analytics helpers and mock stores

## 📦 Installation

```swift
dependencies: [
    .package(url: "https://github.com/sriinnu/Silo.git", from: "1.0.0")
]
```

## 🚀 Quick Start

```swift
import Silo

let client = BrowserCookieClient(
    configuration: .init(decryptionFailurePolicy: .strict)
)

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
for record in records {
    print(record.redactedValue)
}

// Convert to HTTPCookie
let cookies = try client.cookies(matching: query, in: .chrome)
```

## 🌍 Platform Support

| Browser | macOS | Linux | Windows | iOS |
|---------|-------|-------|---------|-----|
| Safari | read | - | - | read (app container) |
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

## Security
Silo reads sensitive cookie data. Apply least privilege and avoid logging cookie values.
Use `BrowserCookieRecord.redactedValue` to safely log cookie data. For strict
decryption failures, set `BrowserCookieClient.Configuration(decryptionFailurePolicy: .strict)`.
On Linux, the insecure "peanuts" fallback is disabled by default. To enable it, set
`SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK=1` (not recommended). For explicit keys, set
`SILO_CHROME_SAFE_STORAGE`. See `SECURITY.md`.

## Testing

```bash
swift test
```

Integration tests build real SQLite cookie stores on disk and validate:
- Chromium + Firefox readers (plain value parsing)
- Safari binarycookies parsing
- Chromium decryption paths (AES-GCM on macOS/Linux, AES-CBC on Linux, DPAPI-wrapped key on Windows)

## 📚 Documentation

```bash
swift package generate-documentation --target Silo
```

## 📚 API Reference

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

### Configuration

```swift
public struct BrowserCookieClient.Configuration {
    public var homeDirectories: [URL]
    public var decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy
}

public enum BrowserCookieDecryptionFailurePolicy {
    case bestEffort
    case strict
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

### BrowserCookieRecord

```swift
public struct BrowserCookieRecord {
    public var redactedValue: String
    public func redactedValue(prefix: Int, suffix: Int) -> String
}
```

## See Also

[Helix](https://github.com/sriinnu/Helix) – Command-line parsing framework

## 📄 License

MIT License - Copyright (c) 2026 Srinivas Pendela

---

**GitHub:** https://github.com/sriinnu/Silo  
**Author:** Srinivas Pendela (hello@srinivas.dev)
