import Foundation
import SwiftData

/// See `Restaurant` for why there are no unique constraints and why every
/// attribute carries a default: CloudKit-backed SwiftData requires it.
/// `id` is a freshly generated UUID per note, so collisions are not a concern.
@Model
final class CommunityNote {
    var id: UUID = UUID()
    var restaurant: Restaurant?
    var chainSlug: String?
    var noteTypeRaw: String = NoteType.syscoVerified.rawValue
    var body: String = ""
    var upvotes: Int = 0
    var downvotes: Int = 0
    var createdAt: Date = Date.now

    var noteType: NoteType {
        get { NoteType(rawValue: noteTypeRaw) ?? .syscoVerified }
        set { noteTypeRaw = newValue.rawValue }
    }

    var netVotes: Int { upvotes - downvotes }

    var isPublic: Bool {
        netVotes >= noteType.thresholdToPublish
    }

    var votesNeeded: Int {
        max(0, noteType.thresholdToPublish - netVotes)
    }

    init(
        noteType: NoteType,
        body: String = "",
        restaurant: Restaurant? = nil,
        chainSlug: String? = nil
    ) {
        self.id = UUID()
        self.noteTypeRaw = noteType.rawValue
        self.body = body
        self.restaurant = restaurant
        self.chainSlug = chainSlug
        self.upvotes = 1
        self.downvotes = 0
        self.createdAt = .now
    }
}
