# Skip Slop — Project Context

## App Overview
Skip Slop is an iOS SwiftUI app that helps users avoid "sloppy" (bad quality) chain restaurants. It shows nearby restaurants on a map with color-coded "slop ratings" (Green+ to Red-) based on a curated chain database and inference heuristics. Users can browse a list view, view restaurant details, read/write community notes (CloudKit), and vote on notes.

## Build & Run
- **Xcode:** Use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` for all xcodebuild commands (active Xcode is Xcode-beta v27.0)
- **Scheme:** `Skip Slop`
- **Bundle ID:** `alpha.Skip-Slop`
- **Team:** `XK665P3866` (Nordic Tug LLC)
- **Deployment target:** iOS 26.4
- **Current version:** 1.0 (build 1)

```bash
# Build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project "Skip Slop.xcodeproj" -scheme "Skip Slop" \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build

# Archive
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project "Skip Slop.xcodeproj" -scheme "Skip Slop" \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/skipslop-archive archive
```

## Architecture
- **SwiftUI** with `@Observable` (Swift Observation) + SwiftData for local persistence
- **MapKit** for map display and restaurant search (`MKLocalSearch`)
- **CloudKit** for community notes sync (public database)
- **File-system-synced groups** (Xcode 16+) — every `.swift` in the source folder is auto-compiled into the app target. No per-file membership checkboxes. **Deleting a .swift file removes it from the build automatically.**

### Key Services
- `ChainDatabase` — curated list of ~150 chain restaurants with slop ratings, loaded from `SeedChains.json`
- `ChainMatcher` — matches map items to known chains
- `RatingInferenceEngine` — infers ratings for non-chain restaurants using keyword heuristics
- `MapSearchService` — wraps `MKLocalSearch` for nearby + text search
- `LocationManager` — `CLLocationManager` wrapper
- `CloudKitService` — community notes CRUD + voting (shared singleton)
- `ContentFilter` — filters inappropriate content in notes

### Data Models (SwiftData)
- `Restaurant` — `@Attribute(.unique)` id, name, rating, ratingSource, chainSlug, coordinates
- `CommunityNote` — text, noteType, upvotes/downvotes, restaurant link

### UI Structure
- `ContentView` — Tab view: Map tab + List tab + Settings tab
- Map tab: `MapContainerView` with `MapSearchBar`, annotations, detail sheet
- List tab: `RestaurantListView` with filter chips
- Detail: `RestaurantDetailView` with `SlopOMeterView`, `CommunityNotesSection`, `AddNoteView`
- Settings: `SettingsView`

### App Store Connect
- **API Key:** `AuthKey_W24PNJH2N2.p8` — Key ID `W24PNJH2N2`, Issuer ID `c785a6e2-e439-404f-9662-172ba89c4fb3`
- **Key location:** `~/.appstoreconnect/private_keys/AuthKey_W24PNJH2N2.p8`
- **Signing:** Automatic, "Apple Distribution: Nordic Tug LLC (XK665P3866)"

## Code Standards
- Use `import os` `Logger` instead of `print()` for logging
- Use `@Observable` pattern (not `ObservableObject`)
- Dark-first design with the `Color+SlopRating` extension palette
