# Silo 🏺

**Cross-platform browser cookie storage extraction**

Silo is a Swift library for reading browser cookies across macOS, iOS, Linux, and Windows. Extract cookies from Safari, Chrome, Firefox, Edge, Brave, Arc, and more with a modern, type-safe API.

## ✨ Features

- **Multi-platform** – macOS, iOS, Linux, Windows
- **Multi-browser** – Safari, Chrome, Firefox, Edge, Brave, Arc, Vivaldi, and more
- **Swift 6** – Full concurrency support
- **Type-safe** – Strongly typed cookie operations
- **Profile-aware** – Multiple browser profile support
- **Query filtering** – Domain matching, expiry handling
- **HTTPCookie** – Direct Foundation integration

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

// Get records
let records = try client.records(matching: query, in: .chrome)

// Convert to HTTPCookie
let cookies = try client.cookies(matching: query, in: .chrome)
```

## 🌍 Platform Support

| Browser | macOS | Linux | Windows | iOS |
|---------|-------|-------|---------|-----|
| Safari | ✅ | - | - | ✅ |
| Chrome | ✅ | ✅ | ✅ | - |
| Firefox | ✅ | ✅ | ✅ | - |
| Edge | ✅ | ✅ | ✅ | - |
| Brave | ✅ | ✅ | ✅ | - |
| Arc | ✅ | - | - | - |

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

## �� Testing

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

## 🔗 See Also

[Helix](https://github.com/sriinnu/Helix) – Command-line parsing framework
