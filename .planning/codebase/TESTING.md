# Testing Patterns

**Analysis Date:** 2026-04-26

## Test Framework

**Runner:**
- None — no XCTest target, no Swift Testing target, and no third-party test framework (Quick, Nimble, etc.) is configured
- The Xcode scheme `CouplesMVP.xcscheme` has a `<TestAction>` block with an empty `<Testables>` list — no test bundle is linked

**Assertion Library:**
- None

**Run Commands:**
- No test commands are available; running tests in Xcode produces no results

## Test File Organization

**Location:**
- No test files exist anywhere in the repository
- `find ios/ -name "*.swift"` returns only 18 production source files; zero test files

**Naming:**
- Not established

**Structure:**
- Not established

## Test Structure

No test suites exist. There is no established test structure to document.

## Mocking

**Framework:**
- None

**Current approach to testability:**
- `SupabaseService` is a `@MainActor final class` singleton accessed via `SupabaseService.shared`
- ViewModels hold `private let service = SupabaseService.shared` directly — there is no protocol abstraction or dependency injection, making unit testing of ViewModels require live network or manual patching
- `WidgetCacheStore` and `ImageCompression` are pure `enum` namespaces with static functions — these are inherently testable without mocking

## Fixtures and Factories

**Test Data:**
- No formal fixtures or factories exist
- `#if DEBUG` blocks in `PairingViewModel` and `CaptureViewModel` provide hardcoded dummy data for manual development use:
  ```swift
  // ios/App/ViewModels/PairingViewModel.swift
  func useDummyPair() {
      pair = Pair(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          ...
      )
  }

  // ios/App/ViewModels/CaptureViewModel.swift
  private static let dummyPairID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  ```

**Location:**
- Debug-only helpers are inline in ViewModel files behind `#if DEBUG` guards

## Coverage

**Requirements:**
- None enforced — no coverage configuration exists

**View Coverage:**
- Not available

## Test Types

**Unit Tests:**
- Not present

**Integration Tests:**
- Not present

**E2E Tests:**
- Not present

**Manual Testing:**
- The only testing approach in use is manual device/simulator testing
- DEBUG bypass buttons (`"⚡ Skip — Dev Only"`, `"⚡ Write dummy widget data"`) in Views and ViewModels enable manual flow testing without live backend data

## Current Testability Assessment

**Easily testable (no changes needed):**
- `ios/App/Services/ImageCompression.swift` — pure static function, takes a `UIImage`, returns `Data?`
- `ios/App/Services/WidgetCacheStore.swift` — static read/write, testable with a real App Group container or by abstracting `FileManager`
- `ios/App/Models/AppModels.swift` — plain `Codable` structs, round-trip encoding is trivially testable
- `ios/App/Models/SharedConstants.swift` — static string constants, trivially verifiable

**Requires refactoring to test:**
- All ViewModels (`AuthViewModel`, `HomeViewModel`, `PairingViewModel`, `CaptureViewModel`) — depend on `SupabaseService.shared` directly; would need a protocol abstraction to inject a mock
- `ios/App/Services/SupabaseService.swift` — singleton `@MainActor` class; no protocol exists for it

## Recommended Test Setup (if tests are added)

**Framework to adopt:**
- XCTest (built-in) or Swift Testing (available from Xcode 16+)
- Add a new test target `CouplesMVPTests` in the Xcode project

**Minimal refactor for ViewModel testability:**
```swift
// Define a protocol
protocol MomentServiceProtocol {
    func fetchLatestMomentFromPartner(pairID: UUID) async throws -> Moment?
}

// SupabaseService conforms
extension SupabaseService: MomentServiceProtocol { ... }

// ViewModel uses protocol
final class HomeViewModel: ObservableObject {
    private let service: MomentServiceProtocol
    init(service: MomentServiceProtocol = SupabaseService.shared) { ... }
}
```

**Test file placement:**
- Conventional location: `ios/Tests/CouplesMVPTests/` (separate target)
- Test file naming: `HomeViewModelTests.swift`, `ImageCompressionTests.swift`

---

*Testing analysis: 2026-04-26*
