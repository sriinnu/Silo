# 🧁 SweetCookieKit

**Cross-platform browser cookie extraction and management for Swift**

SweetCookieKit provides a modern Swift API for reading browser cookies across multiple platforms and browsers. Originally designed for macOS, now expanded for Linux, Windows, iOS, and beyond.

## ✨ Features

- **Multi-platform** – macOS, iOS, Linux, Windows
- **Multi-browser** – Safari, Chrome, Firefox, Edge, Brave, Arc, and more
- **Swift 6** – Full concurrency support
- **Type-safe** – Strong typing for all cookie operations
- **Profile-aware** – Supports multiple browser profiles
- **Query filtering** – Domain matching, expiry handling, custom filters
- **HTTPCookie conversion** – Direct conversion to Foundation types

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/srinivaspendela/SweetCookieKit.git", from: "1.0.0")
]
```

Or use local path:
```swift
dependencies: [
    .package(path: "../Packages/SweetCookieKit")
]
```

## 🚀 Quick Start

### Basic Usage

```swift
import SweetCookieKit

let client = BrowserCookieClient()

// List available stores
let stores = client.stores(for: .chrome)
print("Found \(stores.count) Chrome profiles")

// Query cookies
let query = BrowserCookieQuery(
    domains: ["example.com"],
    domainMatch: .suffix,
    includeExpired: false
)

// Get records
let records = try client.records(matching: query, in: .chrome)
for store in records {
    print("\(store.label): \(store.records.count) cookies")
}

// Convert to HTTPCookie
let cookies = try client.cookies(matching: query, in: .chrome)
```

### Advanced Filtering

```swift
// Exact domain match
let exactQuery = BrowserCookieQuery(
    domains: ["api.example.com"],
    domainMatch: .exact
)

// Multiple domains with suffix match
let multiQuery = BrowserCookieQuery(
    domains: ["example.com", "example.org"],
    domainMatch: .suffix
)

// Include expired cookies
let allQuery = BrowserCookieQuery(
    domains: ["example.com"],
    includeExpired: true
)
```

## 🌍 Platform Support

### macOS
- **Safari** – Full support via `Cookies.binarycookies`
- **Chromium** – Chrome, Chromium, Brave, Edge, Arc, Vivaldi, etc.
- **Firefox** – Full profile support
- **Keychain integration** – Secure decryption of encrypted cookies

### Linux
- **Chromium** – Chrome, Chromium, Brave, Edge
- **Firefox** – Full profile support
- **Encryption** – GNOME Keyring and Secret Service support

### Windows
- **Chromium** – Chrome, Edge, Brave, etc.
- **Firefox** – Full profile support
- **DPAPI** – Windows Data Protection API integration

### iOS
- **WKWebView cookies** – Read cookies from embedded browsers
- **Shared containers** – Access cookies from iOS Safari
- **URL session** – Integration with URLSession cookie storage

## 🔧 Supported Browsers

| Browser | macOS | Linux | Windows | iOS |
|---------|-------|-------|---------|-----|
| Safari | ✅ | - | - | ✅ |
| Chrome | ✅ | ✅ | ✅ | - |
| Firefox | ✅ | ✅ | ✅ | - |
| Edge | ✅ | ✅ | ✅ | - |
| Brave | ✅ | ✅ | ✅ | - |
| Arc | ✅ | - | - | - |
| Chromium | ✅ | ✅ | ✅ | - |
| Vivaldi | ✅ | ✅ | ✅ | - |

## 📝 API Reference

### BrowserCookieClient

Main client for cookie operations:

```swift
public struct BrowserCookieClient {
    public init(configuration: Configuration = Configuration())
    
    // List stores
    public func stores(for browser: Browser) -> [BrowserCookieStore]
    public func stores(in browsers: [Browser]) -> [BrowserCookieStore]
    
    // Query records
    public func records(matching query: BrowserCookieQuery, in browser: Browser) throws -> [BrowserCookieStoreRecords]
    public func records(matching query: BrowserCookieQuery, in store: BrowserCookieStore) throws -> [BrowserCookieRecord]
    
    // Convert to HTTPCookie
    public func cookies(matching query: BrowserCookieQuery, in browser: Browser) throws -> [HTTPCookie]
    public static func makeHTTPCookies(_ records: [BrowserCookieRecord], origin: BrowserCookieOriginStrategy) -> [HTTPCookie]
}
```

### BrowserCookieQuery

Query definition for filtering:

```swift
public struct BrowserCookieQuery {
    public let domains: [String]
    public let domainMatch: BrowserCookieDomainMatch
    public let origin: BrowserCookieOriginStrategy
    public let includeExpired: Bool
    public let referenceDate: Date
}
```

### Browser

Supported browser types:

```swift
public enum Browser {
    case safari, chrome, chromeBeta, chromeCanary
    case firefox
    case edge, edgeBeta, edgeCanary
    case brave, braveBeta, braveNightly
    case arc, arcBeta, arcCanary
    case chromium, vivaldi, helium, chatgptAtlas
}
```

## 🔐 Security & Permissions

### macOS
- **Full Disk Access** required for Safari cookies
- **Keychain prompts** for Chromium encrypted cookies
- **TCC permissions** may be needed

### Linux
- **Keyring access** for encrypted Chromium cookies
- **File permissions** for browser profile directories

### Windows
- **DPAPI** access for encrypted cookies
- **User profile** access rights

### iOS
- **Keychain** access for secure cookies
- **Shared container** entitlements for Safari

## 🌐 Cross-Platform Best Practices

### Path Handling
```swift
// Use FileManager for all path operations
let profilePath = FileManager.default
    .homeDirectoryForCurrentUser
    .appendingPathComponent(".config/google-chrome")

// Platform-specific paths
#if os(macOS)
    let safariPath = "Library/Cookies/Cookies.binarycookies"
#elseif os(Linux)
    let chromePath = ".config/google-chrome"
#elseif os(Windows)
    let chromePath = "AppData\\Local\\Google\\Chrome"
#endif
```

### Error Handling
```swift
do {
    let cookies = try client.cookies(matching: query, in: .chrome)
} catch BrowserCookieError.notFound(let browser, let details) {
    print("\(browser.displayName) not found: \(details)")
} catch BrowserCookieError.accessDenied(let browser, let details) {
    print("Permission denied for \(browser.displayName): \(details)")
} catch {
    print("Failed to load cookies: \(error)")
}
```

## 🧪 Testing

```bash
swift test
```

### Platform-specific tests
```bash
# macOS
swift test --filter SweetCookieKitTests

# Linux (Docker)
docker run --rm -v $PWD:/workspace swift:latest \
    bash -c "cd /workspace && swift test"

# Windows
swift test # Requires Swift for Windows
```

## 📚 Documentation

Generate DocC documentation:
```bash
swift package generate-documentation \
  --target SweetCookieKit \
  --output-path .build/SweetCookieKit.doccarchive
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all platforms build and test successfully
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

Original macOS implementation inspired by browser cookie extraction needs. Expanded to support modern cross-platform Swift development.

## 🔗 See Also

- [Commander](https://github.com/srinivaspendela/Commander) – Command-line parsing framework
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser)
- [HTTPCookie Documentation](https://developer.apple.com/documentation/foundation/httpcookie)
