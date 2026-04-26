# External Integrations

**Analysis Date:** 2026-04-26

## APIs & External Services

**Backend-as-a-Service:**
- Supabase - Primary and only external backend service
  - SDK/Client: `supabase-swift` 2.44.1 (`import Supabase`)
  - Client instantiation: `ios/App/Services/SupabaseService.swift` (singleton `SupabaseService.shared`)
  - Auth: `SUPABASE_URL` and `SUPABASE_ANON_KEY` env vars (injected via `ios/Config/Secrets.xcconfig`)
  - Features used:
    - **Auth** - Anonymous device sign-in (`client.auth.signInAnonymously()`)
    - **PostgREST** - Table queries for `users`, `pairs` (`client.from("...").select/upsert`)
    - **RPC** - Server-side PostgreSQL functions: `create_pair`, `join_pair`, `unlink_pair`, `upload_moment`, `fetch_latest_moment`
    - **Storage** - Private `moments` bucket for JPEG uploads and signed URL generation

## Data Storage

**Databases:**
- Supabase (PostgreSQL 15+) - Hosted by Supabase cloud
  - Connection: via `SUPABASE_URL` (accessed through supabase-swift client, not direct connection string)
  - Client: supabase-swift PostgREST client
  - Schema file: `supabase/schema.sql`
  - Tables: `users`, `pairs`, `moments`, `invite_codes`
  - All tables have Row Level Security (RLS) enabled
  - Extension: `pgcrypto` (for `gen_random_uuid()`)

**File Storage:**
- Supabase Storage - Private bucket named `moments`
  - Object path format: `<pair_id>/<random_uuid>.jpg`
  - Access: signed URLs valid for 24 hours, created via `createSignedURL(path:expiresIn:)`
  - Max upload size: 1 MB (enforced by `ImageCompression.compressedJPEGData` in `ios/App/Services/ImageCompression.swift`)
  - Storage RLS policies restrict insert/select to pair members only

**Caching:**
- Local filesystem (App Group container) - Widget data cache
  - File: `latest_moment.json` in `group.com.example.couples` app group container
  - Written by: `ios/App/Services/WidgetCacheStore.swift`
  - Read by: `ios/Widget/PartnerMomentWidget.swift` (via `WidgetCacheReader`)
  - Widget refreshes every 15 minutes via `WidgetCenter.shared.reloadAllTimelines()`

## Authentication & Identity

**Auth Provider:**
- Supabase Auth - Anonymous authentication
  - Implementation: Device-scoped anonymous sessions via `client.auth.signInAnonymously()`
  - Session persistence: handled by supabase-swift with `emitLocalSessionAsInitialSession: true`
  - No email/password, OAuth, or social login — purely anonymous device identity
  - User rows are created in `public.users` table after anonymous sign-in via `ensureUserRow()`
  - Auth bootstrap: `ios/App/ViewModels/AuthViewModel.swift` calls `bootstrapDeviceSession()` on app start

## Monitoring & Observability

**Error Tracking:**
- None - No third-party error tracking (Sentry, Crashlytics, etc.) detected

**Logs:**
- `print()` statements only (e.g., `WidgetCacheStore.swift`: `print("Widget cache write failed: \(error)")`)
- No structured logging framework

## CI/CD & Deployment

**Hosting:**
- Supabase Cloud - backend infrastructure
- Apple App Store - iOS app distribution (standard Xcode Archive workflow)

**CI Pipeline:**
- None detected - no `.github/workflows/`, `fastlane/`, or other CI configuration present

## Environment Configuration

**Required env vars (via `ios/Config/Secrets.xcconfig`):**
- `SUPABASE_URL` - Full project URL (`https://<project-ref>.supabase.co`)
- `SUPABASE_ANON_KEY` - Public anon key for the Supabase project

**Secrets location:**
- `ios/Config/Secrets.xcconfig` - Local file, not committed to git
- Template: `ios/Config/Secrets.xcconfig.example`
- Auto-created from template by `scripts/setup.sh` if missing

## Webhooks & Callbacks

**Incoming:**
- None - No webhook endpoints detected

**Outgoing:**
- None - No outgoing webhooks detected; all backend interaction is request/response via supabase-swift

## App Group (iOS Inter-Process Communication)

**App Group ID:** `group.com.example.couples`
- Shared between `CouplesMVP` app target and `PartnerMomentWidgetExtension`
- Used to share `latest_moment.json` cache file between app and widget
- Declared in entitlements for both targets: `App/CouplesMVP.entitlements`, `Widget/PartnerMomentWidget.entitlements`

---

*Integration audit: 2026-04-26*
