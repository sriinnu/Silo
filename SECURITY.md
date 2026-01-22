# Security

Silo reads browser cookie stores. This is sensitive data. Treat it as secrets.

## Principles
- Least privilege: only grant the file/keychain access you need.
- No logging: never log full cookie values.
- Redaction: use `BrowserCookieRecord.redactedValue` for safe logging.
- Explicit unlock: on Linux, insecure fallbacks are disabled by default.
- Strict failures: consider `decryptionFailurePolicy: .strict` in production.

## Linux note
Silo uses Secret Service when available. The historical Chromium "peanuts"
fallback is disabled by default. If you must use it (not recommended), set:

```
SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK=1
```

You can also provide an explicit key via:

```
SILO_CHROME_SAFE_STORAGE=your-password
```
