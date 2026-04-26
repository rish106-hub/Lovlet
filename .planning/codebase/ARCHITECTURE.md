# Architecture

**Analysis Date:** 2026-04-26

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with a shared singleton service layer

**Key Characteristics:**
- SwiftUI views are purely declarative and own no business logic
- ViewModels are `@MainActor final class ObservableObject` — all state mutations happen on the main actor
- A single `SupabaseService.shared` singleton mediates all network and storage I/O
- A shared App Group (`group.com.example.couples`) bridges the main app and the WidgetExtension via a JSON file cache
- The backend is serverless (Supabase): all business rules live in PostgreSQL stored procedures with RLS

---

## Layers

**Views:**
- Purpose: Render UI, accept user input, delegate actions to ViewModels
- Location: `ios/App/Views/`
- Contains: SwiftUI `struct View` types — no business logic, no direct service calls
- Depends on: ViewModels (via `@StateObject` / `@ObservedObject`)
- Used by: SwiftUI scene hierarchy rooted at `RootView`

**ViewModels:**
- Purpose: Mediate between Views and the service layer; hold all published state
- Location: `ios/App/ViewModels/`
- Contains: `@MainActor final class` types conforming to `ObservableObject`
- Depends on: `SupabaseService.shared`, `WidgetCacheStore`
- Used by: Views

**Services:**
- Purpose: Encapsulate all external I/O (Supabase API, storage, widget cache, image compression)
- Location: `ios/App/Services/`
- Contains: `SupabaseService` (singleton), `WidgetCacheStore` (static), `ImageCompression` (static), `AppConfig` (static enum)
- Depends on: `Supabase` Swift SDK, `AppConfig`, `WidgetKit`, `UIKit`
- Used by: ViewModels

**Models:**
- Purpose: Value types shared across app and widget
- Location: `ios/App/Models/`
- Contains: `Pair`, `Moment`, `WidgetMoment`, `WidgetMomentState`, `SharedConstants`
- Depends on: `Foundation` only
- Used by: All layers

**Widget Extension:**
- Purpose: Read cached moment data and render a home screen widget
- Location: `ios/Widget/`
- Contains: `PartnerMomentWidget`, `PartnerMomentProvider`, `PartnerMomentWidgetView`, `WidgetCacheReader`
- Depends on: Shared App Group file, `SharedConstants` (via shared model target)
- Used by: iOS home screen / WidgetKit

**Backend (Supabase):**
- Purpose: Database, auth, storage, and all data-mutation business logic
- Location: `supabase/schema.sql`
- Contains: Tables (`users`, `pairs`, `moments`, `invite_codes`), RLS policies, stored procedures
- Depends on: Supabase platform (PostgreSQL + pgcrypto)
- Used by: `SupabaseService`

---

## Data Flow

**App Bootstrap (first launch):**

1. `CouplesMVPApp` → renders `RootView`
2. `RootView` presents `LoginView`, which triggers `AuthViewModel.bootstrapDeviceSession()`
3. `AuthViewModel` calls `SupabaseService.ensureAnonymousSession()` → Supabase anonymous sign-in
4. `AuthViewModel` calls `SupabaseService.ensureUserRow()` → upserts device user into `users` table
5. `AuthViewModel.isReady = true` → `RootView` transitions to widget onboarding or pairing/home

**Screen Routing (`RootView`):**

```
isReady == false        → LoginView
widgetOnboardingDone == false → WidgetOnboardingView
pair == nil             → PairingView
pair != nil             → HomeView
```

`RootView` uses `@AppStorage("widgetOnboardingDone")` for widget onboarding persistence and triggers `PairingViewModel.loadPair()` whenever auth becomes ready.

**Pairing Flow:**

1. User A: `PairingView` → `PairingViewModel.createInviteCode()` → `SupabaseService.createPairInviteCode()` → RPC `create_pair` → returns 8-char code
2. User B: enters code → `PairingViewModel.joinPair()` → `SupabaseService.joinPair(inviteCode:)` → RPC `join_pair` → creates `pairs` row
3. Both: `PairingViewModel.loadPair()` → `SupabaseService.fetchMyPair()` → `pairs` table select → `pair` published property updated → `RootView` routes to `HomeView`

**Moment Upload:**

1. `CaptureMomentView` collects image (via `PhotosPicker`) and text
2. `CaptureViewModel.uploadMoment(image:pairID:)` called
3. `ImageCompression.compressedJPEGData(_:)` compresses image to ≤1 MB
4. `SupabaseService.uploadMoment(image:text:pairID:)`:
   - Uploads JPEG to Storage bucket `moments` at path `<pair_id>/<uuid>.jpg`
   - Calls RPC `upload_moment(image_path, message)` to insert row into `moments`
5. On success, `CaptureViewModel.uploadSuccess = true` → View dismisses

**Moment Fetch & Widget Cache:**

1. `HomeView.task` → `HomeViewModel.loadCached()` (sync, reads App Group JSON) → then `HomeViewModel.refresh(pairID:)` (async)
2. `SupabaseService.fetchLatestMomentFromPartner(pairID:)`:
   - Calls RPC `fetch_latest_moment(target_pair_id)` — returns partner's latest moment only
   - Creates a signed storage URL (24h expiry)
3. `HomeViewModel` saves `WidgetMomentState.moment(...)` via `WidgetCacheStore.save(_:)` → writes JSON to App Group container → calls `WidgetCenter.shared.reloadAllTimelines()`
4. On network failure, `HomeViewModel` falls back to `loadCached()` so the last-seen moment remains visible

**Widget Rendering:**

1. WidgetKit calls `PartnerMomentProvider.getTimeline(...)` (refreshes every 15 minutes)
2. `WidgetCacheReader.read()` reads `latest_moment.json` from the App Group container
3. `PartnerMomentWidgetView` renders based on `WidgetMomentState`: `.noPair`, `.noMoment`, or `.moment(WidgetMoment)`

**State Management:**
- Published state lives in ViewModels; views observe via `@StateObject` / `@ObservedObject`
- Widget state is persisted as JSON in the shared App Group container (`group.com.example.couples/latest_moment.json`)
- Widget onboarding completion stored in `@AppStorage("widgetOnboardingDone")`
- No in-memory global state store; each ViewModel is independent

---

## Key Abstractions

**SupabaseService:**
- Purpose: Single gateway for all Supabase operations (auth, database RPC, storage)
- File: `ios/App/Services/SupabaseService.swift`
- Pattern: `@MainActor` singleton (`static let shared`); exposes typed async throws functions

**WidgetCacheStore:**
- Purpose: Read/write `WidgetMomentState` to the App Group container; triggers widget timeline reload on write
- File: `ios/App/Services/WidgetCacheStore.swift`
- Pattern: Static enum namespace with `save(_:)` / `read()` functions

**AppConfig:**
- Purpose: Provides compile-time-validated config values sourced from `Info.plist` (populated by `Secrets.xcconfig`)
- File: `ios/App/Services/AppConfig.swift`
- Pattern: Static enum; `fatalError` on misconfiguration to surface setup issues at launch

**SharedConstants:**
- Purpose: Single source of truth for values used by both the app target and the widget extension target
- File: `ios/App/Models/SharedConstants.swift`
- Pattern: Static enum; referenced by both `AppConfig` and `WidgetConfig`

**Supabase Stored Procedures:**
- Purpose: All pair and moment mutations run as `security definer` RPC functions, keeping business rules server-side and out of the client
- File: `supabase/schema.sql`
- Key functions: `create_pair`, `join_pair`, `unlink_pair`, `upload_moment`, `fetch_latest_moment`

---

## Entry Points

**iOS App:**
- Location: `ios/App/CouplesMVPApp.swift`
- Triggers: iOS app launch (`@main`)
- Responsibilities: Creates the SwiftUI `WindowGroup` → `RootView`

**Widget Extension:**
- Location: `ios/Widget/PartnerMomentWidget.swift`
- Triggers: WidgetKit timeline request, home screen render (`@main`)
- Responsibilities: Reads App Group cache, returns `Timeline<PartnerMomentEntry>` every 15 minutes

**Root Navigation:**
- Location: `ios/App/Views/RootView.swift`
- Triggers: Rendered by `CouplesMVPApp`
- Responsibilities: Owns `AuthViewModel` and `PairingViewModel`, performs conditional routing across all top-level app states

---

## Error Handling

**Strategy:** ViewModels catch errors from the service layer and publish them as `@Published var errorMessage: String?`; Views display error text inline and offer retry buttons.

**Patterns:**
- All ViewModel async functions wrap service calls in `do { ... } catch { errorMessage = error.localizedDescription }`
- `CaptureViewModel` performs one automatic retry on upload failure before surfacing the error
- `HomeViewModel.refresh` falls back to `loadCached()` on network error to preserve last-seen widget data
- `AppConfig` uses `fatalError` for missing config to prevent silent misconfiguration at runtime
- Supabase RPC functions raise PostgreSQL exceptions (e.g., "Invalid or expired invite code") that surface as `LocalizedError` via the Supabase Swift SDK

---

## Cross-Cutting Concerns

**Logging:** `print(...)` only; used in `WidgetCacheStore` for cache write failures. No structured logging framework.

**Validation:** Input validation is split: client guards (e.g., empty text check in `CaptureViewModel`) and authoritative server-side validation inside `security definer` Postgres functions.

**Authentication:** Supabase anonymous device auth — no user account required. `SupabaseService.ensureAnonymousSession()` is called once at bootstrap; the Supabase SDK persists the session automatically. All subsequent requests carry the anonymous JWT.

**App Group / Extension boundary:** The app and widget share data exclusively through `group.com.example.couples/latest_moment.json`. The widget never calls Supabase directly.

---

*Architecture analysis: 2026-04-26*
