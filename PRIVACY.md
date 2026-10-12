# Skip Slop Privacy Policy

**Last updated: October 11, 2026**

Skip Slop has no accounts, no analytics, no ads, and no tracking. This page lists everything the app stores and sends.

## Location

Skip Slop asks for your location while you use the app, to show restaurants near you. Your location is used on your device and sent to Apple MapKit as the area to search, the same way the Maps app does. Skip Slop never saves your location, never sends it to CloudKit, and never sends it to us. You can deny location access and search for a city or zip code instead.

## Community notes and votes

Notes and votes are the only data that leaves your device for Skip Slop's own storage, and only when you post a note or tap a vote button. They are stored in the app's public database in Apple CloudKit:

- **A note:** the note type, the text you wrote, when you posted it, and which restaurant it's about (the chain name, or the restaurant's map coordinates for an independent place).
- **A vote:** which note it's for and whether it's up or down. You get one vote per note. Tapping the same vote again removes it.

CloudKit attaches an anonymous identifier to each note and vote you create. Apple assigns this identifier for Skip Slop only, and it's tied to your iCloud account. It lets the app keep you to one vote per note, but it doesn't reveal your name, email address, or Apple Account to us or to other users. Skip Slop doesn't collect your name, email address, phone number, or contacts.

Notes are public. Anyone using the app can read them, including notes that are still waiting for votes. Don't put personal information in a note.

## Stored on your device

- Restaurants you've posted notes about, and your notes (SwiftData).
- Your votes, whether you've seen the intro, and an internal setup flag (app preferences).

Places you only look at are not saved.

## Third-party services

- **Apple MapKit:** map display and restaurant search. See [Apple's Privacy Policy](https://www.apple.com/privacy/).
- **Apple CloudKit:** stores community notes and votes. See [Apple's Privacy Policy](https://www.apple.com/privacy/).

Skip Slop doesn't sell or share data with anyone else, and doesn't use advertising or analytics SDKs.

## Moderation

Notes are checked on your device for abusive language before they're posted. A note counts as confirmed once it gets enough net upvotes. Until then it's shown as waiting for votes.

## Retention and deletion

Notes and votes stay in CloudKit until they're removed. To remove your vote, tap it again. To have a note removed, open an issue at the link below. Data on your device is deleted when you delete the app.

## Contact

For privacy questions, open an issue at [github.com/ukaia/Skip-Slop](https://github.com/ukaia/Skip-Slop).
