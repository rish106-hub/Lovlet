# Codebase Concerns

**Analysis Date:** 2026-04-26

## Tech Debt

**Placeholder Bundle Identifiers and App Group:**
- Issue: `com.example` bundle prefix and `group.com.example.couples` app group are placeholder values. `CFBundleDisplayName` is still "CouplesMVP" not the real product name "LoveLet".
- Files: `ios/project.yml` (lines 3, 34, 40, 60, 63), `ios/App/Models/SharedConstants.swift` (line 4)
- Impact: Cannot ship to the App Store with `com.example` identifiers. Changing the bundle ID and app group in production invalidates all existing widget entitlements and `@AppStorage` keys on user devices.
- Fix approach: Replace `com.example` with the real reverse-domain before any TestFlight build. Update `SharedConstants.appGroupID`, both entitlements files, and `project.yml` in one coordinated change.

**Internal Code Name Exposed to Users:**
- Issue: `WidgetOnboardingView` instructs users to search for "CouplesMVP" by name on the home screen. The product is branded "LoveLet".
- Files: `ios/App/Views/WidgetOnboardingView.swift` (line 35)
- Impact: Onboarding instruction is wrong for production; users will not find the widget.
- Fix approach: Replace hardcoded string with the real `CFBundleDisplayName` (injected at build time or a shared constant).

**Silent Retry on Upload Masks Errors:**
- Issue: `CaptureViewModel.uploadMoment` silently retries the upload once on failure. If both attempts fail, only the second error is surfaced to the user. If the first attempt partially succeeded (storage upload complete but RPC failed), the silent retry can produce a duplicate storage object.
- Files: `ios/App/ViewModels/CaptureViewModel.swift` (lines 36–43)
- Impact: Potential duplicate storage objects; error messages may be misleading (second attempt's error, not first).
- Fix approach: Remove the inline retry. Use exponential back-off via a dedicated retry utility if retry logic is required. Alternatively, make the `upload_moment` RPC idempotent by keying on the image path.

**`Secrets.xcconfig` Committed to Git:**
- Issue: `ios/Config/Secrets.xcconfig` is tracked by git (`git ls-files` confirms it). The `.gitignore` comment acknowledges this is temporary but the file is not excluded.
- Files: `ios/Config/Secrets.xcconfig`, `.gitignore` (comment on last line)
- Impact: Real credentials will be leaked to the repository history as soon as a developer fills in `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Fix approach: Add `ios/Config/Secrets.xcconfig` to `.gitignore` immediately. Use CI environment variables or a secrets manager for automated builds. The `.example` file already exists for bootstrapping.

**`WidgetCacheReader` Duplicates `WidgetCacheStore.read`:**
- Issue: The widget extension contains its own private `WidgetCacheReader` enum that is a line-for-line duplicate of `WidgetCacheStore.read()` in the main app target.
- Files: `ios/Widget/PartnerMomentWidget.swift` (lines 9–24), `ios/App/Services/WidgetCacheStore.swift` (lines 20–33)
- Impact: Any change to the cache format must be made in two places or the widget reads stale/incompatible data.
- Fix approach: Move the shared read logic to `App/Models/` or a shared framework so both targets import from one source of truth (the widget already imports `App/Models`).

**Double `WidgetMoment` Construction in `HomeViewModel.refresh`:**
- Issue: A `WidgetMoment` is constructed twice from identical data when a moment is fetched successfully — once for `WidgetCacheStore.save` and once for `cachedWidgetMoment`.
- Files: `ios/App/ViewModels/HomeViewModel.swift` (lines 28–39)
- Impact: Minor allocation waste, and any future change to construction logic risks the two copies diverging.
- Fix approach: Construct one `WidgetMoment`, assign to a `let`, then pass it to both call sites.

**`SUPABASE_URL` Prepends `https://` in Info.plist:**
- Issue: `project.yml` sets `SUPABASE_URL: "https://$(SUPABASE_URL)"`. If the xcconfig value already contains `https://`, the resolved URL becomes `https://https://...` and `AppConfig` will `fatalError` at launch.
- Files: `ios/project.yml` (line 26), `ios/Config/Secrets.xcconfig.example`
- Impact: Developer misconfiguration causes a crash rather than a clear error. The xcconfig example shows the full URL including scheme, making double-prepending likely.
- Fix approach: Either store only the hostname in `Secrets.xcconfig` and keep the `https://` prefix in `project.yml`, or remove the prefix from `project.yml` and rely on the full URL in the xcconfig. Document the expected format clearly.

## Security Considerations

**`Secrets.xcconfig` Not Gitignored:**
- Risk: Credentials committed to git are permanently exposed in history even after removal.
- Files: `ios/Config/Secrets.xcconfig`, `.gitignore`
- Current mitigation: None — file is tracked.
- Recommendations: Add to `.gitignore` before any developer fills in real credentials. Rotate any credentials that have already been committed.

**Signed Image URLs Persisted with No Expiry Check:**
- Risk: Signed Supabase Storage URLs generated with `expiresIn: 60 * 60 * 24` (24 hours) are written into the on-disk widget cache (`latest_moment.json` in the App Group container). The widget reads and renders this URL without checking whether it has expired. The cached `WidgetMoment` in `HomeView` is also rendered directly from the JSON without re-validation.
- Files: `ios/App/Services/SupabaseService.swift` (line 105), `ios/App/Services/WidgetCacheStore.swift`, `ios/Widget/PartnerMomentWidget.swift` (line 64), `ios/App/Views/HomeView.swift` (line 33)
- Current mitigation: Refreshing from the network generates a new signed URL.
- Recommendations: Store the raw image path (not the signed URL) in `WidgetMoment`. Re-generate the signed URL at display time, or cache the expiry timestamp and re-sign before rendering.

**Anonymous Auth — No Account Recovery Path:**
- Risk: Anonymous Supabase auth ties user identity to a device session. If the user deletes the app, loses the device, or the session token is purged, they lose their pair link and all moments permanently with no recovery path.
- Files: `ios/App/Services/SupabaseService.swift` (line 41), `ios/App/ViewModels/AuthViewModel.swift`
- Current mitigation: None.
- Recommendations: Consider linking anonymous auth to an email or Apple ID before the pair is established, or add a "transfer pair" flow before this concern becomes a user-facing problem at scale.

**No Input Validation on Invite Code Client-Side:**
- Risk: The invite code text field accepts any input and sends it directly to the `join_pair` RPC. There is no client-side format check (expected: 8 uppercase alphanumeric characters).
- Files: `ios/App/Views/PairingView.swift` (line 21), `ios/App/ViewModels/PairingViewModel.swift` (line 33)
- Current mitigation: Server-side validation raises an exception for invalid codes.
- Recommendations: Add a `.onChange` validator to trim whitespace and limit input to 8 alphanumeric characters before enabling the join button. This improves UX and reduces unnecessary RPC calls.

## Performance Bottlenecks

**`AsyncImage` Used Without Caching:**
- Problem: Both `HomeView` and `PartnerMomentWidget` use `AsyncImage` directly, which has no persistent disk cache. Every app launch or widget render re-downloads the image from the signed URL.
- Files: `ios/App/Views/HomeView.swift` (lines 15, 33), `ios/Widget/PartnerMomentWidget.swift` (line 64)
- Cause: SwiftUI `AsyncImage` uses `URLSession` with default caching, but widget extensions have constrained memory and the in-memory URL cache is discarded on every widget refresh (every 15 minutes).
- Improvement path: Cache the image data to the App Group container alongside `latest_moment.json` so the widget renders immediately without a network request. Use `SDWebImageSwiftUI` or `Kingfisher` in the main app for persistent disk caching.

**Widget Polls Every 15 Minutes with No Push Trigger:**
- Problem: The widget timeline refreshes on a fixed 15-minute schedule via `policy: .after(nextRefresh)`. There is no push notification or Supabase Realtime channel to trigger an immediate refresh when a partner posts a new moment.
- Files: `ios/Widget/PartnerMomentWidget.swift` (line 42)
- Cause: No push notification or background task integration exists.
- Improvement path: Integrate APNs push notifications (via Supabase Edge Functions or a server-side trigger) that call `WidgetCenter.shared.reloadAllTimelines()` when a new moment is uploaded.

**Image Compression Loop Not Bounded Tightly:**
- Problem: `ImageCompression.compressedJPEGData` iterates in 0.1 quality steps from 0.8 down to 0.2 (up to 6 iterations). For very high-resolution camera images this can still exceed 1 MB and return a result above the `maxBytes` limit because the loop exits early rather than enforcing the size constraint strictly.
- Files: `ios/App/Services/ImageCompression.swift` (lines 8–11)
- Cause: The loop condition is `data.count > maxBytes && quality > 0.2`, so if quality reaches 0.2 and data is still above `maxBytes` the oversized data is returned.
- Improvement path: After the loop, either reject the image or continue compressing with a finer step. Return `nil` (triggering `imageCompressionFailed`) if the final result still exceeds `maxBytes`.

## Fragile Areas

**`WidgetCacheStore` Silences File Write Errors:**
- Files: `ios/App/Services/WidgetCacheStore.swift` (lines 14–16)
- Why fragile: Write failures are swallowed with a `print`. If the App Group container is unavailable (e.g., entitlement misconfiguration), the widget shows stale or empty state with no diagnostic path.
- Safe modification: Surface errors via a `Result` or `throws` signature so callers can react. At minimum, log errors through a structured logging channel.
- Test coverage: No tests exist for this path.

**`AppConfig` Uses `fatalError` for Configuration Issues:**
- Files: `ios/App/Services/AppConfig.swift` (lines 8, 12, 15, 26)
- Why fragile: Misconfigured build settings crash the app at launch with no user-facing recovery path. This is intentional for developer feedback but means CI/CD pipelines with incorrectly set xcconfig values will produce a crashing build rather than a compile-time error.
- Safe modification: Add a pre-build script phase (in `project.yml`) that validates xcconfig values before compilation, converting the runtime crash into a build failure.
- Test coverage: None — fatalError paths cannot be unit tested.

**`RootView` Navigation Depends on `@AppStorage` Key Stability:**
- Files: `ios/App/Views/RootView.swift` (line 6)
- Why fragile: The `widgetOnboardingDone` key is a bare string literal. Changing the key, changing the bundle ID, or using a different `UserDefaults` suite causes the onboarding gate to reset for all existing users.
- Safe modification: Define the key as a constant in `SharedConstants` and consider whether this flag should migrate when the bundle ID changes.
- Test coverage: None.

**`fetchMyPair` Returns Arbitrary First Result:**
- Files: `ios/App/Services/SupabaseService.swift` (lines 72–79)
- Why fragile: The query does `select().limit(1)` on the `pairs` table without filtering by the current user ID. It relies entirely on RLS to scope the result. If RLS is ever misconfigured or the session is in an unexpected state, this could return a wrong pair or an empty result with no error.
- Safe modification: Add an explicit `.eq("user1_id", currentUserID)` / `.or` filter as a defence-in-depth measure. The SQL-level `get_my_pair_id()` function is already the correct pattern — the Swift query should mirror it.
- Test coverage: None.

## Scaling Limits

**Moments Table Has No Retention Policy:**
- Current capacity: Unlimited rows per pair.
- Limit: Storage costs and query performance degrade indefinitely as moments accumulate. `fetch_latest_moment` is indexed and efficient today, but the storage bucket will grow without bound.
- Scaling path: Add a scheduled Supabase Edge Function or database trigger to prune moments older than N days per pair (e.g., keep last 30 or last 7 days).

**Invite Codes Table Has No Cleanup:**
- Current capacity: One row per invite code generation.
- Limit: Expired and consumed codes accumulate in `public.invite_codes` indefinitely.
- Scaling path: Add a periodic DELETE for `expires_at < now() - interval '7 days'` via a Supabase scheduled function.

## Missing Critical Features

**No Push Notifications:**
- Problem: Partners have no way to know a new moment has been shared except by manually opening the app or waiting up to 15 minutes for the widget to poll.
- Blocks: Real-time "moment received" experience expected for a couples app.

**No Account Linking / Recovery:**
- Problem: Anonymous device auth with no fallback means users who reinstall or switch devices permanently lose their pair.
- Blocks: Reliable user retention once the app has real users.

**No Moment History:**
- Problem: Only the latest partner moment is fetched and displayed. There is no scroll/feed view of past moments.
- Blocks: Core engagement loop beyond the MVP.

**No Rate Limiting on Moment Uploads:**
- Problem: A user can call `uploadMoment` in a tight loop, uploading unlimited images to storage with no server-side throttle.
- Blocks: Cost control and abuse prevention before any public launch.

## Test Coverage Gaps

**Zero Automated Tests:**
- What's not tested: All ViewModels, all Services, all SQL functions, all RLS policies.
- Files: Entire `ios/App/` tree, `supabase/schema.sql`
- Risk: Any refactor of core logic (pairing flow, upload, widget cache) can break silently. RLS policy changes have no regression coverage.
- Priority: High — the pairing and upload flows are the core product paths.

---

*Concerns audit: 2026-04-26*
