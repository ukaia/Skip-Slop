import Foundation
import Testing
@testable import Skip_Slop

@Suite("Votes")
struct VoteStoreTests {
    @Test func tappingSameDirectionUndoes() {
        #expect(VoteStore.toggled(current: .up, tapped: .up) == nil)
        #expect(VoteStore.toggled(current: .down, tapped: .down) == nil)
    }

    @Test func tappingOtherDirectionSwitches() {
        #expect(VoteStore.toggled(current: .up, tapped: .down) == .down)
        #expect(VoteStore.toggled(current: nil, tapped: .up) == .up)
    }

    @Test func tallyReplacesVoteWithoutDoubleCounting() {
        let base = VoteTally(upvotes: 3, downvotes: 1)
        #expect(base.replacing(nil, with: .up) == VoteTally(upvotes: 4, downvotes: 1))
        #expect(base.replacing(.up, with: .down) == VoteTally(upvotes: 2, downvotes: 2))
        #expect(base.replacing(.down, with: nil) == VoteTally(upvotes: 3, downvotes: 0))
        #expect(VoteTally().replacing(.up, with: nil) == VoteTally())
    }

    @Test func publishThresholdUsesNetVotes() {
        let type = NoteType.allCases[0]
        let atThreshold = VoteTally(upvotes: type.thresholdToPublish, downvotes: 0)
        #expect(atThreshold.isPublic(for: type))
        #expect(atThreshold.votesNeeded(for: type) == 0)
        #expect(!VoteTally().isPublic(for: type) || type.thresholdToPublish <= 0)
    }

    @Test func voteRecordNameIsDeterministicPerUserAndNote() {
        let a = CloudKitService.voteRecordName(noteID: "n1", userRecordName: "_u1")
        #expect(a == CloudKitService.voteRecordName(noteID: "n1", userRecordName: "_u1"))
        #expect(a != CloudKitService.voteRecordName(noteID: "n1", userRecordName: "_u2"))
        #expect(a != CloudKitService.voteRecordName(noteID: "n2", userRecordName: "_u1"))
    }

    @Test func storePersistsVotesAcrossInstances() throws {
        let suite = "VoteStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = VoteStore(defaults: defaults)
        store.set(.down, for: "note-1")
        #expect(VoteStore(defaults: defaults).vote(for: "note-1") == .down)

        store.set(nil, for: "note-1")
        #expect(VoteStore(defaults: defaults).vote(for: "note-1") == nil)
    }

    @Test func newNotesStartWithNoVotes() {
        let note = CommunityNote(noteType: NoteType.allCases[0])
        #expect(note.upvotes == 0)
        #expect(note.downvotes == 0)
    }
}
