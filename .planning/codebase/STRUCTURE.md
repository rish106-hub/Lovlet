# Codebase Structure

**Analysis Date:** 2026-04-26

## Directory Layout

```
idea/                              # Repo root
├── ios/                           # All iOS source code
│   ├── App/                       # Main app target
│   │   ├── CouplesMVPApp.swift    # @main app entry point
│   │   ├── Info.plist             # App target Info.plist (references xcconfig keys)
│   │   ├── CouplesMVP.entitlements # App Group entitlement
│   │   ├── Models/                # Shared value types (used by app + widget)
│   │   ├── Services/              # Service layer (Supabase, cache, config, utilities)
│   │   ├── ViewModels/            # ObservableObject ViewModels (@MainActor)
│   │   └── Views/                 # SwiftUI views
│   ├── Widget/                    # PartnerMomentWidget extension target
│   │   ├── PartnerMomentWidget.swift  # @main widget entry point
│   │   ├── Info.plist             # Widget extension Info.plist
│   │   └── PartnerMomentWidget.entitlements  # App Group entitlement (same group as app)
│   ├── Config/                    # Xcode build configuration
│   │   ├── Secrets.xcconfig       # Developer-local secrets (gitignored)
│   │   └── Secrets.xcconfig.example  # Template — committed to repo
│   └── CouplesMVP.xcodeproj/      # Xcode project file
├── supabase/
│   └── schema.sql                 # Full Postgres schema, RLS policies, stored procedures
├── scripts/
│   ├── setup.sh                   # One-time dev environment setup
│   ├── check-prereqs.sh           # Validates required tools are installed
│   └── apply-supabase-schema.sh   # Applies schema.sql to a Supabase project
├── .planning/
│   └── codebase/                  # GSD codebase map documents
├── .claude/                       # Claude Code project config
└── README.md                      # Project README
```

---

## Directory Purposes

**`ios/App/Models/`:**
- Purpose: Plain value types and shared constants used across both the app and widget targets
- Contains: `Codable` structs (`Pair`, `Moment`, `WidgetMoment`), enums (`WidgetMomentState`), and `SharedConstants`
- Key files:
  - `ios/App/Models/AppModels.swift` — all domain model types
  - `ios/App/Models/SharedConstants.swift` — App Group ID, storage bucket name, widget cache filename

**`ios/App/Services/`:**
- Purpose: All external I/O and cross-cutting utilities; no SwiftUI dependencies
- Contains: Supabase client wrapper, App Group cache, image compression, build config accessor
- Key files:
  - `ios/App/Services/SupabaseService.swift` — singleton wrapping the Supabase Swift SDK
  - `ios/App/Services/WidgetCacheStore.swift` — reads/writes `WidgetMomentState` JSON to App Group container
  - `ios/App/Services/AppConfig.swift` — reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Info.plist
  - `ios/App/Services/ImageCompression.swift` — JPEG compression utility (target ≤1 MB)

**`ios/App/ViewModels/`:**
- Purpose: Mediate between Views and Services; own all `@Published` state
- Contains: `@MainActor final class ObservableObject` types — one per screen or concern
- Key files:
  - `ios/App/ViewModels/AuthViewModel.swift` — anonymous session bootstrap
  - `ios/App/ViewModels/PairingViewModel.swift` — pair creation, joining, unlinking
  - `ios/App/ViewModels/HomeViewModel.swift` — latest moment fetch and widget cache sync
  - `ios/App/ViewModels/CaptureViewModel.swift` — moment upload with auto-retry

**`ios/App/Views/`:**
- Purpose: Declarative SwiftUI UI; no direct service calls
- Contains: SwiftUI `struct View` types — one per screen
- Key files:
  - `ios/App/Views/RootView.swift` — top-level router; owns `AuthViewModel` and `PairingViewModel`
  - `ios/App/Views/LoginView.swift` — device bootstrap / anonymous auth screen
  - `ios/App/Views/WidgetOnboardingView.swift` — guides user to add the home screen widget
  - `ios/App/Views/PairingView.swift` — invite code generation and entry
  - `ios/App/Views/HomeView.swift` — latest partner moment display
  - `ios/App/Views/CaptureMomentView.swift` — photo picker + text field for sending a moment

**`ios/Widget/`:**
- Purpose: WidgetKit extension — renders partner's latest moment on the home screen
- Contains: `@main Widget`, `TimelineProvider`, and widget view; reads only from App Group cache
- Key file: `ios/Widget/PartnerMomentWidget.swift`

**`ios/Config/`:**
- Purpose: Xcode build configuration for injecting secrets into `Info.plist`
- Key files:
  - `ios/Config/Secrets.xcconfig.example` — committed template showing required keys
  - `ios/Config/Secrets.xcconfig` — developer-local file (gitignored); must be created from example

**`supabase/`:**
- Purpose: Single source of truth for the Supabase backend
- Key file: `supabase/schema.sql` — tables, indexes, triggers, RLS policies, and all stored procedures

**`scripts/`:**
- Purpose: Developer tooling for onboarding and database management
- Key files:
  - `scripts/setup.sh` — one-time setup
  - `scripts/apply-supabase-schema.sh` — applies `schema.sql` to the project's Supabase instance

---

## Key File Locations

**Entry Points:**
- `ios/App/CouplesMVPApp.swift`: iOS app `@main`
- `ios/App/Views/RootView.swift`: Top-level navigation router
- `ios/Widget/PartnerMomentWidget.swift`: Widget extension `@main`

**Configuration:**
- `ios/Config/Secrets.xcconfig`: Local secrets (gitignored — must create from `.example`)
- `ios/Config/Secrets.xcconfig.example`: Template for required xcconfig keys
- `ios/App/Services/AppConfig.swift`: Runtime config accessor (validates keys at launch)
- `ios/App/Models/SharedConstants.swift`: Shared constants (App Group ID, bucket name)

**Core Logic:**
- `ios/App/Services/SupabaseService.swift`: All Supabase interaction
- `ios/App/Services/WidgetCacheStore.swift`: App ↔ Widget data bridge
- `supabase/schema.sql`: Backend schema and all business-rule stored procedures

**Testing:**
- No test targets detected

---

## Naming Conventions

**Files:**
- SwiftUI views: `PascalCase` ending in `View` — e.g., `HomeView.swift`, `CaptureMomentView.swift`
- ViewModels: `PascalCase` ending in `ViewModel` — e.g., `HomeViewModel.swift`
- Services/utilities: `PascalCase` describing the concern — e.g., `SupabaseService.swift`, `WidgetCacheStore.swift`, `ImageCompression.swift`
- Models: grouped in `AppModels.swift`; shared constants in `SharedConstants.swift`

**Types:**
- All types: `PascalCase`
- ViewModels: `final class`, marked `@MainActor`
- Services: `final class` (singleton) or `enum` namespace (static utilities)
- Models: `struct` conforming to `Codable` and `Identifiable`

**Properties/Functions:**
- `camelCase` throughout
- Published state properties use descriptive nouns: `isReady`, `isLoading`, `errorMessage`, `latestMoment`
- Async functions named as imperative verbs: `loadPair()`, `createInviteCode()`, `uploadMoment(image:pairID:)`

**Supabase / Database:**
- Tables: `snake_case` plural — `users`, `pairs`, `moments`, `invite_codes`
- Columns: `snake_case` — `user1_id`, `created_at`, `image_url`
- RPC functions: `snake_case` verb phrases — `create_pair`, `join_pair`, `upload_moment`, `fetch_latest_moment`
- Swift `CodingKeys` map `snake_case` DB columns to `camelCase` Swift properties

---

## Where to Add New Code

**New screen:**
- View: `ios/App/Views/NewFeatureView.swift`
- ViewModel: `ios/App/ViewModels/NewFeatureViewModel.swift`
- Wire into routing in `ios/App/Views/RootView.swift` or via a `NavigationLink` in an existing view

**New Supabase operation:**
- Add a `security definer` stored procedure in `supabase/schema.sql`
- Add the corresponding RLS policy in `supabase/schema.sql`
- Add a typed `async throws` method to `ios/App/Services/SupabaseService.swift`
- Call it from the appropriate ViewModel — never directly from a View

**New shared model type:**
- Value types used only by the app: add to `ios/App/Models/AppModels.swift`
- Constants or types used by both app and widget: add to `ios/App/Models/SharedConstants.swift` or `AppModels.swift` (both are compiled into both targets)

**New utility:**
- Pure, stateless helpers with no SwiftUI dependency: add as a `static` method on a new or existing `enum` in `ios/App/Services/`

**New widget state:**
- Extend `WidgetMomentState` enum in `ios/App/Models/AppModels.swift`
- Update `WidgetCacheStore.save` / `read` if needed (`ios/App/Services/WidgetCacheStore.swift`)
- Update `PartnerMomentWidgetView` switch statement in `ios/Widget/PartnerMomentWidget.swift`

---

## Special Directories

**`.planning/codebase/`:**
- Purpose: GSD codebase map documents consumed by planning and execution agents
- Generated: Yes (by `/gsd-map-codebase`)
- Committed: Yes

**`ios/CouplesMVP.xcodeproj/`:**
- Purpose: Xcode project definition, scheme configuration, and SPM package resolution
- Generated: Partially (SPM lockfile is generated; project.pbxproj is hand-managed)
- Committed: Yes

**`ios/Config/Secrets.xcconfig`:**
- Purpose: Developer-local secret injection into the Xcode build
- Generated: No (created manually from `Secrets.xcconfig.example`)
- Committed: No (gitignored)

---

*Structure analysis: 2026-04-26*
