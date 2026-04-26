# Coding Conventions

**Analysis Date:** 2026-04-26

## Naming Patterns

**Files:**
- Views: `PascalCase` matching the SwiftUI struct name — `HomeView.swift`, `PairingView.swift`, `CaptureMomentView.swift`
- ViewModels: `PascalCase` with `ViewModel` suffix — `AuthViewModel.swift`, `HomeViewModel.swift`, `CaptureViewModel.swift`
- Models: `PascalCase` describing the domain entity — `AppModels.swift`, `SharedConstants.swift`
- Services: `PascalCase` describing the capability — `SupabaseService.swift`, `WidgetCacheStore.swift`, `ImageCompression.swift`
- Widget: `PascalCase` with descriptive name — `PartnerMomentWidget.swift`

**Types (structs, classes, enums):**
- `PascalCase` throughout — `Pair`, `Moment`, `WidgetMoment`, `WidgetMomentState`
- Error types nested inside their owner as `ServiceError` — e.g. `SupabaseService.ServiceError`
- Enum-based namespaces for constants/utilities: `enum AppConfig { ... }`, `enum SharedConstants { ... }`, `enum ImageCompression { ... }`, `enum WidgetCacheStore { ... }`

**Properties and Functions:**
- `camelCase` for all stored properties, computed properties, and function names
- Boolean state properties named as predicates: `isReady`, `isLoading`, `isUploading`, `isChecking`
- Published error properties named `errorMessage: String?`
- Success state named `uploadSuccess: Bool`
- Private helpers named with leading verbs: `syncWidgetNoPairIfNeeded()`, `verify()`, `loadCached()`

**Constants:**
- Static `let` in `enum` namespaces — `SharedConstants.appGroupID`, `AppConfig.momentsBucket`
- `#if DEBUG` static constants follow the same `camelCase` convention — `dummyPairID`

## Code Style

**Formatting:**
- No `.editorconfig`, `.swiftformat`, or `swiftlint.yml` detected — style is maintained manually
- 4-space indentation (Swift default)
- Opening brace on same line as declaration
- Trailing closure syntax used consistently for SwiftUI body modifiers
- Guard statements preferred for early-exit over nested `if` chains:
  ```swift
  guard let userID = currentUserID else { return }
  guard !inviteCode.isEmpty else { return }
  ```

**Linting:**
- No SwiftLint config found — no enforced lint rules

## Import Organization

**Order:**
1. `Foundation` (always first when needed)
2. Apple frameworks (`SwiftUI`, `UIKit`, `WidgetKit`, `PhotosUI`) — alphabetical
3. Third-party SDKs (`Supabase`)

**Aliases:**
- None used

## Access Control

- ViewModels and Services default to `internal` (implicit)
- Singleton init is `private init()`
- Helper functions not part of public interface are `private`
- Widget-internal types prefixed with `private enum` — `WidgetConfig`, `WidgetCacheReader`
- `final` is applied to all `class` declarations — `final class AuthViewModel`, `final class SupabaseService`

## Concurrency

- All ViewModels and `SupabaseService` are decorated `@MainActor` at the class level
- Async operations are `async throws` or `async` (non-throwing where errors are silently handled)
- `defer { isLoading = false }` pattern used consistently to reset loading state after async scope:
  ```swift
  isLoading = true
  defer { isLoading = false }
  do {
      try await service.someCall()
  } catch {
      errorMessage = error.localizedDescription
  }
  ```
- `Task { await viewModel.someMethod() }` used in SwiftUI button actions to bridge sync to async
- `.task { }` and `.task(id:) { }` modifiers used for lifecycle-bound async work in Views

## Error Handling

**Pattern:**
- All async operations wrapped in `do/catch`
- Errors surfaced to UI via `errorMessage: String?` on the ViewModel using `error.localizedDescription`
- No error is silently swallowed without at minimum setting `errorMessage`
- Domain errors typed as `LocalizedError` enums nested inside the service:
  ```swift
  enum ServiceError: LocalizedError {
      case imageCompressionFailed
      var errorDescription: String? { ... }
  }
  ```
- Fallback logic on retry is inlined inline (e.g. `CaptureViewModel` retries upload once on failure)
- Cache fallback on network failure with an explanatory comment:
  ```swift
  } catch {
      errorMessage = error.localizedDescription
      // Keep showing cached moment in poor network conditions.
      loadCached()
  }
  ```

**Fatal errors for misconfiguration:**
- `fatalError(...)` is used in `AppConfig` to crash early on missing build settings — this is intentional and documented inline

## SwiftUI Patterns

**ViewModel ownership in Views:**
- Owning view (that creates the VM): `@StateObject private var viewModel = SomeViewModel()`
- Views that receive an existing VM: `@ObservedObject var viewModel: SomeViewModel`
- Example: `RootView` owns `AuthViewModel` and `PairingViewModel` via `@StateObject`; `HomeView` receives `pairingViewModel` via `@ObservedObject`

**Navigation:**
- `NavigationStack` used (not deprecated `NavigationView`)
- `NavigationLink` for push navigation; `@Environment(\.dismiss)` for programmatic dismissal

**State:**
- `@AppStorage` used for persisted boolean flags — `widgetOnboardingDone`
- `@State` for local transient UI state within a View

**Conditional rendering:**
- `if/else if/else` chains inside `Group { }` blocks for multi-state display
- `@unknown default` always included in `AsyncImage` phase switches

## Logging

- `print(...)` used for non-critical internal errors (e.g. widget cache write failure)
- No structured logging framework in use

## Comments

**When to comment:**
- `// MARK: - Section Name` used in `SupabaseService` to group related methods
- Single-line inline comments explain non-obvious intent (e.g. retry rationale, cache fallback reasoning)
- No block comments or doc comments (`///`) found in the codebase

## DEBUG Helpers

- `#if DEBUG` / `#endif` blocks used consistently in both Views and ViewModels
- DEBUG helpers are visually distinct using `"⚡"` prefix on button labels and `.orange` foreground style
- Debug shortcuts bypass real network calls via dummy UUIDs or `Task.sleep` simulation

## Module Design

**Exports:**
- All types are implicitly `internal` — no explicit `public` API surface (single-module app)

**Barrel Files:**
- Not used — files import only what they need directly

---

*Convention analysis: 2026-04-26*
