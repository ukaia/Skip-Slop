# Skip Slop

An iOS app that rates restaurants on whether they cook real food or reheat
mass-produced product from a broadline distributor.

Open the map, and every restaurant near you carries a colour. Green means real
food. Red means Sysco or US Foods. The point is to answer one question before
you sit down: *is this place going to microwave a $30 burger at me?*

## How a rating is decided

Three sources, in order of confidence.

**1. The chain database.** `Skip Slop/Data/SeedChains.json` holds 186 known
chains with a rating, a distributor, a parent company and a source. If MapKit
hands us a name that matches one of them, that is the rating.

Matching is token-based and deliberately cautious. `ChainDatabase.match(name:)`
will only assert an accusatory rating — orange, red, red minus — on strong
evidence: an exact name, a known alias, or a multi-token run such as "Olive
Garden" inside "Olive Garden Italian Restaurant". A single shared token is not
enough. An independent called "Longhorn Cafe" shares one token with LongHorn
Steakhouse and gets no rating from the database at all, because a wrong red on
a local restaurant is the failure this app cannot afford.

**2. The inference engine.** For anything not in the database,
`RatingInferenceEngine` reads the name and the MapKit category and guesses,
returning a confidence alongside the rating. A taqueria or a bakery leans
green; a name in the shape of a franchise leans orange; a plain sit-down
restaurant gets the benefit of the doubt at yellow. These are heuristics and
the UI is supposed to say so.

**3. Community notes.** Users report what they have seen — a delivery truck, a
price, a tip screen that starts at 22%. Notes are held back until they clear a
vote threshold (`NoteType.thresholdToPublish`) and sync through the CloudKit
public database.

## Building

Requires Xcode with an iOS 26 SDK and a simulator runtime at or above the
deployment target.

```bash
xcodebuild -project "Skip Slop.xcodeproj" -scheme "Skip Slop" \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Sign simulator builds.** With `CODE_SIGNING_ALLOWED=NO` the iCloud entitlement
is stripped, `CKContainer.default()` cannot resolve a container, and the app
dies on the first frame. Build under the team, or pass
`-allowProvisioningUpdates`, so the simulated entitlements are applied.

```bash
xcodebuild test -project "Skip Slop.xcodeproj" -scheme "Skip Slop" \
  -destination 'platform=iOS Simulator,name=iPhone 17' -allowProvisioningUpdates
```

Releasing to TestFlight is documented separately in the workspace guide
`GUIDES/SKIP_SLOP_TESTFLIGHT_RELEASE.md`.

## Layout

| Path | What lives there |
|---|---|
| `Models/` | SwiftData `@Model` types, `SlopRating`, `NoteType` |
| `Data/` | The chain database, the matcher, `SeedChains.json` |
| `Services/` | Inference, MapKit search, location, CloudKit, content filtering |
| `Views/` | Map, list, detail and settings |
| `Skip SlopTests/` | Chain matching and content filter tests |

## Constraints worth knowing before you change things

**SwiftData here is CloudKit-backed.** `.modelContainer(for:)` switches to
`NSPersistentCloudKitContainer` whenever the iCloud entitlement is present,
which is every signed build. That imposes three rules on `@Model` types, and
breaking any one of them stops the *entire store* from loading — the app still
launches and looks fine while silently saving nothing:

- every attribute optional or carrying a default
- every relationship optional
- no `@Attribute(.unique)`

`Restaurant` identity is therefore enforced in code, by fetching on `id` before
inserting, not by a constraint.

**Ratings are claims about real businesses.** A rating asserts something
specific and damaging about a named restaurant. Keep the evidence rules in
`ChainDatabase.match(name:)` conservative, and prefer no rating over a wrong
one.

## Known gaps

- `SeedChains.json` provenance is thin: 63 of 186 entries cite only the string
  "Industry reporting", and no entry carries a source URL or a date. Ratings
  should carry structured, checkable evidence.
- The chain database ships in the bundle, so correcting a wrong rating needs an
  App Store release.
- Community notes cannot live-update. That needs the Push Notifications
  capability on the App ID plus the `remote-notification` background mode;
  neither is enabled today.
- Notes require 3 votes to publish (5 when contested) with no user base yet, so
  nothing has ever cleared the threshold.
