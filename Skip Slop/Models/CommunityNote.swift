import Foundation
import SwiftData

@Model
final class CommunityNote {
    @Attribute(.unique) var id: UUID
    var restaurant: Restaurant?
    var chainSlug: String?
    var noteTypeRaw: String
    var body: String
    var upvotes: Int
    var downvotes: Int
    var createdAt: Date

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
