# Couples Moments MVP

Lean MVP for two-person "latest moment sharing" with:
- iOS app (`SwiftUI`)
- iOS widget (`WidgetKit`)
- Supabase backend (`Postgres`, `Auth`, `Storage`)

## Product Scope
- One pair only (`1:1`)
- One latest visible moment in UI/widget
- Moment payload: `selfie + short text`
- No chat, no reactions, no feed

## Project Layout
- `supabase/schema.sql`: DB schema, RPC functions, RLS policies
- `ios/App/Models`: core app models
- `ios/App/Services`: Supabase, upload, cache services
- `ios/App/ViewModels`: screen state + actions
- `ios/App/Views`: login, pairing, capture, home
- `ios/Widget`: WidgetKit implementation

## Supabase Setup
1. In Supabase dashboard, enable Anonymous auth.
2. Get your Postgres connection string and export it:
   - `export SUPABASE_DB_URL='postgresql://...'`
3. Apply schema:
   - `./scripts/apply-supabase-schema.sh`

This creates tables, RPC functions, RLS policies, and the private `moments` storage bucket.

## iOS Setup
1. Fill `ios/Config/Secrets.xcconfig`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
2. Generate project:
   - `./scripts/setup.sh`
3. Open `ios/CouplesMVP.xcodeproj`.
4. In Signing & Capabilities, set:
   - your Team for app + widget targets
   - App Group `group.com.example.couples` on both targets
5. Build and run on iPhone/simulator.

## Quick Validation
- Run `./scripts/check-prereqs.sh` before opening Xcode.
- It verifies:
  - full Xcode presence
  - xcodegen
  - secrets configured

## Minimal Data/API Flow
- App bootstraps anonymous device auth (no email/OTP UI)
- `create_pair()` => returns invite code
- `join_pair(invite_code)` => creates pair
- `upload_moment(image_path, message)` => writes latest candidate moment
- `fetch_latest_moment(target_pair_id)` => gets partner's latest moment only
- iOS calls these via Supabase RPC from `SupabaseService`
- App writes latest state to app-group cache for widget
- Widget reads cache and refreshes timeline every ~15 minutes

## Reliability Notes
- Image compressed before upload (<1 MB target)
- Upload retries once on failure
- Widget uses local cached state for resilience
