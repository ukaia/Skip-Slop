# Skip Slop — v2 Polish Plan

**Scope:** bug fixes, UI/UX improvements, performance, modernization, cleanup. No new features.
**Critical:** The build is currently BROKEN — `ContentView 2.swift` and `ContentView 3.swift` are misplaced XCTest stubs that fail to compile. Fix this first.

---

## Implementation Order

### Phase 1: Fix Build + Cleanup (do first)

**C1. Delete `ContentView 2.swift` and `ContentView 3.swift`** — BUILD-BREAKING
- These are XCTest scaffolding stubs (`import XCTest`, `@testable import YourApp`) that compile into the app target because the project uses a file-system-synchronized group. They cause: `error: Unable to resolve module dependency: 'XCTest'` and `error: Unable to resolve module dependency: 'YourApp'`.
- **Fix:** Delete both files outright. No code references either type.

**C2. Remove dead `RestaurantRowView`** — `Views/List/RestaurantRowView.swift` is never referenced (the list uses inline `MapItemRowView` in `RestaurantListView.swift`). Delete it.

**C3. Remove dead CloudKit methods** — In `Services/CloudKitService.swift`, delete `uploadRestaurantRating`, `fetchChainRating`, and `checkAccountStatus` — all defined but never called.

**C4. Remove dead `MapSearchService.search(query:region:)`** — never called directly (only `smartSearch` and `searchNearby` are used).

**C5. Fix "Coming Soon" section** — In `Views/Settings/SettingsView.swift`, remove "Cloud Sync for Community Notes" from "Coming Soon" (it's already implemented). Update remaining items to "In Development" or remove the section.

### Phase 2: Critical Bugs

**B1. List tab shows empty state until visiting Map** — `mapResults` is `@State` in `ContentView` passed by value to `RestaurantListView`. Fix: trigger `searchNearby` once on first appear regardless of tab (move to `ContentView` or add `.task` to `RestaurantListView` when `mapResults.isEmpty`).

**B2. Location updates never started** — In `Views/Map/MapContainerView.swift`, `requestPermission()` is called but `startUpdating()` never is (only in delegate callback). If permission already granted, no callback fires, so `location` stays nil. Fix: in `LocationManager`, check `authorizationStatus` in `requestPermission()` — if already authorized, call `startUpdatingLocation()`. Also hoist `LocationManager` to a shared `@State` instead of a `private let` inside the view (recreated on every render).

**B4. Vote dedup missing** — `CommunityNote.init` sets `upvotes = 1` (author self-vote) but there's no "did I vote" flag. Users can tap upvote repeatedly. Fix: add local `Set<UUID>` of voted note IDs in UserDefaults, disable the vote button once used.

**B7. Inferred ratings persisted on open** — `RestaurantDetailView.loadOrCreateRestaurant` inserts a new `Restaurant` with `ratingSource: .community` on every map-tap of an inferred place. Fix: don't persist on open; only create the record when the user takes an explicit action (adds a note). Keep inferred rating as transient display.

### Phase 3: Performance

**P1. Chain matching runs on every render** — In `MapContainerView` and `RestaurantListView`, each annotation/list row calls `ChainMatcher.match` + `RatingInferenceEngine.infer` on every view re-render (camera pan triggers re-render). Fix: precompute `[RatedItem]` in a `.task`/`.onChange(of: mapResults)`, store in `@State`. Both Map and List consume the precomputed array.

**P2. ContentFilter recompiles ~15 regexes on every call** — Fix: precompile as `static let` (NSRegularExpression is thread-safe).

**P3. RatingInferenceEngine compiles regex on every call** — `try? NSRegularExpression(pattern: "^[a-z]+'s\\b")` created per inference. Fix: hoist to `private static let`.

**P5. No debounce on map pan** — `onMapCameraChange(.onEnd)` fires `loadNearbyRestaurants` on every pan, cancelling/restarting. Fix: add ~0.5s debounce (Task.sleep at start, abort if cancelled).

### Phase 4: UI/UX Polish

**U1. No loading state on Map** — Show `ProgressView` overlay while first search is in flight. Replace the fixed 1.5s sleep with: request location → on first fix set region → trigger search. Fall back to default region after timeout if denied.

**U2. No permission-denied UI** — If location denied, show alert linking to Settings (`UIApplication.openSettingsURLString`). If not determined, call `requestPermission()` first.

**U4. No close button on detail sheet** — Add toolbar close button (`Button("Done") { dismiss }`).

**U6. Vote buttons give no feedback** — Add `sensoryFeedback`/haptics on tap. Optimistic UI update for cloud notes.

**U8. Search bar improvements** — Add `submitLabel(.search)`. Show spinner while search active.

### Phase 5: Modernization

**M3. Replace print() with Logger** — ~10 print calls across `CloudKitService`, `LocationManager`, `MapContainerView`. Replace with `import os` + `private let logger = Logger(subsystem: "alpha.Skip-Slop", category: "...")`.

**B3. CloudKit vote race condition** — `vote()` does fetch-modify-save (lost votes under concurrency). Fix: use `CKModifyRecordsOperation` with `.changedKeys` save policy, or retry on `CKError.serverRecordChanged`.

**B10. ContentFilter all-caps check too aggressive** — Rejects legitimate notes like "I PAID $30 FOR A BURGER". Fix: raise threshold to >95% and length ≥ 20, or exclude currency patterns.

### Phase 6: Version Bump
- Set `MARKETING_VERSION = 2.0` and `CURRENT_PROJECT_VERSION = 2` in project.pbxproj
- Commit all changes to git

---

## Verification
```bash
cd "/Users/ukaiarogers/Documents/xcode local/Skip Slop"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project "Skip Slop.xcodeproj" -scheme "Skip Slop" \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```
Confirm `BUILD SUCCEEDED` with zero warnings.
