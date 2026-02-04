# TODO
This file tracks the implementation backlog to reach the README scope.

## macOS (priority)
- ~~Validate Safari binarycookies parsing against real-world samples (fixture + optional local integration test).~~
- ~~Investigate SameSite extraction for Safari/WebKit binarycookies (documented as unavailable in current format).~~

## Cross-platform
- ~~Windows: Keyring integration and DPAPI edge cases.~~
- ~~Linux: Keyring/libsecret hardening.~~
- ~~iOS: entitlements and shared container guidance.~~

## Core API
- ~~CRUD operations for cookies (in-memory mock store).~~
- ~~Mock stores for tests.~~
- ~~Keep README examples aligned with implemented APIs.~~

## Recently completed
- Scoped iOS store discovery to WebKit/Safari browsers only.
- Added regex path filtering via `BrowserCookieQuery.pathPattern`.
- Added SVG branding assets and clarified README usage/limitations.
- Added optional Safari real-world parsing integration test.
- Expanded cookie metadata fields (created/lastAccessed/priority/partition/sameParty).
- Added JSON export helpers with Codable export models.
- Added JSON import helpers plus sync/analytics summaries.
- Added JSON schema versioning for exports.
- Added a bundled Safari binarycookies fixture file for tests.
- Added npm metadata wrapper (`package.json` + `index.js`).
- Documented iOS entitlements guidance and keyring hardening knobs.
- Added in-memory mock store CRUD helpers for tests.
