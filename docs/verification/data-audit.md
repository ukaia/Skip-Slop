# Data collection audit

Audited against `polish/phase2-redesign`, build 4 (2.0). Read from the code; CloudKit writes could not be checked live because the simulator test builds are unsigned (no iCloud entitlement).

## Stored on the device

### SwiftData (`Skip_SlopApp` → `.modelContainer(for: [Restaurant.self, CommunityNote.self])`)

| Model | Fields | Written when |
|---|---|---|
| `Restaurant` | `id` (`<chainSlug or "independent">_<lat>_<lon>` of the **restaurant**), `name`, `chainSlug`, `latitude`, `longitude` (restaurant's), `address`, `slopRatingRaw`, `ratingSourceRaw`, `createdAt`, `updatedAt` | Only in `RestaurantDetailView.persistRestaurant()`, which is called only by `AddNoteView.submitNote` → **only when a note is posted**. Viewing a place does not save it (`loadRestaurant()` only fetches). |
| `CommunityNote` | `id` (UUID), `restaurant` (relationship), `chainSlug`, `noteTypeRaw`, `body`, `upvotes`, `downvotes`, `createdAt` | Only in `AddNoteView.submitNote`. Vote counts on the user's own unsynced local notes change in `NoteCardView`. |

### UserDefaults / `@AppStorage`

| Key | Type | Purpose |
|---|---|---|
| `hasSeenOnboarding` | Bool | `ContentView`, `SettingsView` (Replay Intro), `OnboardingView.seenKey` |
| `note_votes_v1` | `[noteID: Int]` | `VoteStore` — this user's vote per note (+1/−1) |
| `cloudkit_schema_initialized_v2` | Bool | `CloudKitService.initializeSchemaIfNeeded` (now DEBUG builds only) |
| `UITestScreenshots`, `skipOnboarding`, `showOnboarding`, `mockData`, `openDetail`, `openSettings` | Bool (argument domain, read only) | `LaunchOptions`, DEBUG only; never written |

Nothing else is persisted: no location, no search history, no viewed places, no device identifiers.

## Sent off the device

### Apple MapKit (Apple's service, not ours)

`MapSearchService` sends the visible map region (centred on the user's location when allowed) and the search text to `MKLocalSearch` / `MKLocalPointsOfInterestRequest`, and city/zip queries for geocoding. The app does not store the location.

### CloudKit public database (`iCloud.alpha.Skip-Slop`)

| Record type | Record name | Fields | Written when |
|---|---|---|---|
| `CommunityNote` | `note_<noteUUID>` | `noteID`, `restaurantID` (restaurant's slug+coordinates, not the user's), `chainSlug`, `noteType`, `body`, `createdAt` | `CloudKitService.uploadNote`, called only from `AddNoteView.submitNote` |
| `NoteVote` | `vote_<noteID>_<userRecordName>` | `noteID`, `direction` (1/−1) | `CloudKitService.setVote` from `VoteStore.toggle`; un-voting deletes the record |

CloudKit also stores system metadata on each record, including `creatorUserRecordID` — the user's app-scoped, pseudonymous CloudKit user record name. The vote record name embeds the same ID. That's what makes it **one vote per user per note**: the record name is deterministic, so a second vote overwrites the first, and `fetchNotes` excludes the user's own vote record from `othersTally` so it's never double-counted.

DEBUG builds additionally write and immediately delete one seed `CommunityNote` and `NoteVote` on first launch to create the development schema. **Fixed in this pass:** that also ran in Release/TestFlight builds against the production database for every new install; it is now `#if DEBUG`.

Reads: `CommunityNote` by `chainSlug` or `restaurantID`; `NoteVote` by `noteID IN …`. No user lookup or discoverability is requested.

## Confirmations

- [x] Places reach SwiftData only when a note is posted (`persistRestaurant` is only passed to `AddNoteView` as `resolveRestaurant`, and only invoked in `submitNote`).
- [x] Places reach CloudKit only as the `restaurantID`/`chainSlug` of a posted note.
- [x] Notes: type, body, date, restaurant reference. No user location, name, or device ID in fields.
- [x] One vote per user per note, enforced by deterministic record names (`CloudKitService.voteRecordName`); tests in `VoteStoreTests`.
- [x] No analytics, ads, tracking, or third-party SDKs (no package dependencies in the project).

## PRIVACY.md discrepancies (fixed)

| Old statement | Reality |
|---|---|
| "No personal identifiers are attached to notes." | CloudKit attaches the app-scoped user record ID to every note and vote, and vote record names embed it. Reworded to describe this. |
| Votes not mentioned | Votes are stored in CloudKit. Added. |
| "Notes require community votes to reach public visibility." | Notes waiting for votes are readable by all users under "Waiting for votes". Corrected. |
| "Notes are moderated … before becoming publicly visible." | Only an on-device word filter (`ContentFilter`). Corrected. |
| "You may report inappropriate content through the app." | There is no report feature. Removed; see "Needs Kai". |
| "Local data (saved restaurants)" | Only restaurants you've posted notes about are saved. Corrected. |

Also added `Skip Slop/PrivacyInfo.xcprivacy` (there wasn't one). The app uses `UserDefaults`, a required-reason API, so App Store Connect expects a privacy manifest declaring it (reason `CA92.1`). The manifest's collected-data section matches the labels below.

## Recommended App Store privacy labels (Kai sets these in App Store Connect)

**Data used to track you:** none.

**Data linked to you:**

| Category → Type | Purpose | Why |
|---|---|---|
| User Content → Other User Content | App Functionality | Community note text, type, and votes, stored in CloudKit with the creator's ID |
| Identifiers → User ID | App Functionality | CloudKit's app-scoped user record ID on each note/vote and in vote record names |

**Not collected:** Location. It's used on device and sent to Apple MapKit only to answer the search in real time; the developer never receives or keeps it. Contact info, health, financial, browsing, search history, diagnostics, usage data, purchases: none.

If Kai decides the pseudonymous CloudKit ID doesn't count as linking, "Other User Content" could be marked *Not linked* and "User ID" dropped. Linked is the conservative choice. Whatever is chosen, keep `PrivacyInfo.xcprivacy` consistent with it.

## Needs Kai

- **No way to report or block a note.** App Review Guideline 1.2 requires apps with user-generated content to offer a way to flag objectionable content and block abusive users, plus a published contact. Adding it needs a new CloudKit record type (e.g. `NoteReport`) deployed to production in the CloudKit Dashboard, which this pass was told not to touch.
- **Production CloudKit schema.** With the seed writes now DEBUG-only, make sure the `CommunityNote` and `NoteVote` record types, and the indexes the queries need (`chainSlug`, `restaurantID`, `noteID` queryable; `createdAt` sortable), are deployed to Production.
- Set the privacy labels above.
