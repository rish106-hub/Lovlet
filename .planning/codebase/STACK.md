# Technology Stack

**Analysis Date:** 2026-04-26

## Languages

**Primary:**
- Swift 5.9+ - All iOS app and widget code (`ios/App/`, `ios/Widget/`)
- SQL (PostgreSQL dialect) - Supabase schema and stored procedures (`supabase/schema.sql`)

**Secondary:**
- Bash - Project setup and utility scripts (`scripts/`)

## Runtime

**Environment:**
- iOS 17.0 minimum deployment target (set in `ios/project.yml`)
- Targets: iPhone and iPad (`TARGETED_DEVICE_FAMILY: "1,2"`)

**Package Manager:**
- Swift Package Manager (SPM) - integrated via Xcode
- Lockfile: `ios/CouplesMVP.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (present, version 3)

## Frameworks

**Core:**
- SwiftUI - Primary UI framework; all views use `some View` body pattern (`ios/App/Views/`)
- WidgetKit - Home screen widget extension (`ios/Widget/PartnerMomentWidget.swift`)
- UIKit - Image capture and compression utilities (`ios/App/Services/ImageCompression.swift`)
- Foundation - Base types, JSON coding, file I/O throughout

**Build/Dev:**
- XcodeGen - Generates `CouplesMVP.xcodeproj` from `ios/project.yml`; installed via Homebrew

## Key Dependencies

**Critical:**
- `supabase-swift` 2.44.1 (pinned) / from 2.0.0 (spec minimum) - Backend client covering auth, database PostgREST queries, storage, and RPC calls
  - Product used: `Supabase` (umbrella product)
  - Source: `https://github.com/supabase/supabase-swift.git`

**Transitive (auto-resolved via supabase-swift):**
- `swift-crypto` 4.5.0 - Cryptographic primitives
- `swift-asn1` 1.7.0 - ASN.1 encoding (JWT/auth support)
- `swift-http-types` 1.5.1 - Typed HTTP values
- `swift-clocks` 1.0.6 - Point-Free clock abstractions
- `swift-concurrency-extras` 1.3.2 - Swift concurrency helpers
- `xctest-dynamic-overlay` 1.9.0 - Test overlay support

## Configuration

**Environment:**
- Secrets stored in `ios/Config/Secrets.xcconfig` (gitignored; not committed)
- Template at `ios/Config/Secrets.xcconfig.example`
- Required keys:
  - `SUPABASE_URL` - Full Supabase project URL (e.g. `https://YOUR_PROJECT.supabase.co`)
  - `SUPABASE_ANON_KEY` - Supabase anon/public API key
- Keys injected into `App/Info.plist` at build time via `ios/project.yml` Info.plist properties
- Read at runtime via `Bundle.main.object(forInfoDictionaryKey:)` in `ios/App/Services/AppConfig.swift`

**Build:**
- `ios/project.yml` - XcodeGen spec; single source of truth for targets, schemes, dependencies, entitlements
- Two build configurations: `Debug` and `Release` — both read from `Config/Secrets.xcconfig`
- Bundle ID prefix: `com.example` (placeholder; production requires replacement)

## Platform Requirements

**Development:**
- macOS with Xcode installed at `/Applications/Xcode.app`
- `xcodegen` CLI (Homebrew: `brew install xcodegen`)
- Supabase project with schema applied (`scripts/apply-supabase-schema.sh`)
- `ios/Config/Secrets.xcconfig` filled with real project credentials

**Production:**
- iOS App Store distribution (standard Xcode Archive + export flow)
- Supabase cloud backend (no self-hosted infra required)

---

*Stack analysis: 2026-04-26*
