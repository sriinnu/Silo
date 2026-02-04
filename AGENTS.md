# Silo Agent Guide

## Purpose
Silo is a Swift package that reads browser cookies across platforms. The README
describes many features that are not implemented yet, so prioritize closing the
gap between the public API and actual behavior.

## Repo layout
- `Sources/Silo/BrowserCookieClient.swift`: main entry point and cookie loading.
- `Sources/Silo/BrowserCookieModels.swift`: public models and query types.
- `Tests/`: unit + integration tests for readers and filtering.

## High-priority focus
- Keep README and `TODO.md` aligned with implemented platform coverage.
- Validate Safari binarycookies parsing against real-world samples.
- Maintain cross-platform decryption support and strict failure handling.

## Workflow
- Keep public API and README in sync; update documentation when behavior changes.
- Add unit tests when implementing any new cookie reader or filtering logic.
- Prefer small, per-browser modules instead of a monolith in `BrowserCookieClient`.
- Keep directories/files modular and DRY, with clear documentation for each module.

## Common commands
- Run tests: `swift test`
- Generate docs: `swift package generate-documentation --target Silo`

## Updates
- 2026-02-04: Added JSON schema versioning and browser field availability docs.
- 2026-02-04: Added JSON export support, created a Safari fixture file with resource-backed test, expanded cookie metadata fields (created/lastAccessed/priority/partition/sameParty), added a permissions checklist, and prepared npm metadata wrapper.
- 2026-02-04: Added JSON import + analytics/sync helpers, mock store CRUD docs, and closed remaining TODO items with documented limitations.
- 2026-02-04: Refined SVG branding (full logo + mark), expanded README clarity sections, documented limitations, added optional Safari real-world parsing test, and expanded cookie metadata fields (created/lastAccessed/priority/partition/sameParty).
- 2026-02-03: Added path regex filtering (`BrowserCookieQuery.pathPattern`), scoped iOS stores to WebKit-only, refreshed README notes, and added a logo asset.
