import SwiftUI
import SwiftData

struct CommunityNotesSection: View {
    let restaurantID: String
    let chainSlug: String?

    @Query private var allNotes: [CommunityNote]
    @State private var cloudNotes: [CloudNote] = []
    @State private var isLoadingCloud = false

    private var localNotes: [CommunityNote] {
        allNotes.filter { note in
            if note.restaurant?.id == restaurantID {
                return true
            }
            if let chainSlug, note.chainSlug == chainSlug {
                return true
            }
            return false
        }
        .sorted { $0.netVotes > $1.netVotes }
    }

    private var voteStore: VoteStore { .shared }

    /// Local notes not yet visible in CloudKit. Once synced, the cloud copy (which
    /// carries everyone's votes) replaces the author's local copy.
    private var unsyncedLocalNotes: [CommunityNote] {
        let cloudIDs = Set(cloudNotes.map(\.id))
        return localNotes.filter { !cloudIDs.contains($0.id.uuidString) }
    }

    private func isPublic(_ note: CloudNote) -> Bool {
        note.tally(with: voteStore.vote(for: note.id)).isPublic(for: note.noteType)
    }

    private var publicCloudNotes: [CloudNote] {
        cloudNotes.filter(isPublic)
    }

    private var pendingCloudNotes: [CloudNote] {
        cloudNotes.filter { !isPublic($0) }
    }

    private var hasAnyNotes: Bool {
        !localNotes.isEmpty || !cloudNotes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Community Notes", systemImage: "person.2.fill")
                    .font(.headline)

                Spacer()

                if isLoadingCloud {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if !hasAnyNotes {
                emptyState
            } else {
                // Public cloud notes
                if !publicCloudNotes.isEmpty {
                    ForEach(publicCloudNotes) { note in
                        CloudNoteCardView(note: note)
                    }
                }

                // Local notes
                ForEach(unsyncedLocalNotes) { note in
                    NoteCardView(note: note, isPending: !note.isPublic)
                }

                // Pending cloud notes
                if !pendingCloudNotes.isEmpty {
                    Text("Pending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(pendingCloudNotes) { note in
                        CloudNoteCardView(note: note, isPending: true)
                    }
                }
            }
        }
        .task(id: restaurantID) { await loadCloudNotes() }
    }

    private func loadCloudNotes() async {
        isLoadingCloud = true
        defer { isLoadingCloud = false }

        let service = CloudKitService.shared
        var notes: [CloudNote] = []

        if let chainSlug {
            notes = await service.fetchNotes(forChainSlug: chainSlug)
        }

        if notes.isEmpty {
            let restaurantNotes = await service.fetchNotes(forRestaurantID: restaurantID)
            notes.append(contentsOf: restaurantNotes)
        }

        cloudNotes = notes
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No community notes yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Be the first to report!")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Local Note Card

struct NoteCardView: View {
    let note: CommunityNote
    let isPending: Bool

    @Environment(\.modelContext) private var modelContext
    private var voteStore: VoteStore { .shared }

    var body: some View {
        let noteID = note.id.uuidString
        NoteCardLayout(
            icon: note.noteType.icon,
            color: note.noteType.color,
            displayName: note.noteType.displayName,
            noteBody: note.body,
            createdAt: note.createdAt,
            upvotes: note.upvotes,
            downvotes: note.downvotes,
            votesNeeded: note.votesNeeded,
            isPending: isPending,
            myVote: voteStore.vote(for: noteID),
            isVoting: voteStore.inFlight.contains(noteID),
            onVote: { direction in
                Task {
                    await voteStore.toggle(direction, noteID: noteID) { old, new in
                        let tally = VoteTally(upvotes: note.upvotes, downvotes: note.downvotes)
                            .replacing(old, with: new)
                        note.upvotes = tally.upvotes
                        note.downvotes = tally.downvotes
                        try? modelContext.save()
                    }
                }
            }
        )
    }
}

// MARK: - Cloud Note Card

struct CloudNoteCardView: View {
    let note: CloudNote
    var isPending: Bool = false
    private var voteStore: VoteStore { .shared }

    var body: some View {
        let myVote = voteStore.vote(for: note.id)
        let tally = note.tally(with: myVote)
        NoteCardLayout(
            icon: note.noteType.icon,
            color: note.noteType.color,
            displayName: note.noteType.displayName,
            noteBody: note.body,
            createdAt: note.createdAt,
            upvotes: tally.upvotes,
            downvotes: tally.downvotes,
            votesNeeded: tally.votesNeeded(for: note.noteType),
            isPending: isPending,
            isCloud: true,
            myVote: myVote,
            isVoting: voteStore.inFlight.contains(note.id),
            onVote: { direction in
                Task { await voteStore.toggle(direction, noteID: note.id) }
            }
        )
    }
}

// MARK: - Shared Layout

struct NoteCardLayout: View {
    let icon: String
    let color: Color
    let displayName: String
    let noteBody: String
    let createdAt: Date
    let upvotes: Int
    let downvotes: Int
    let votesNeeded: Int
    let isPending: Bool
    var isCloud: Bool = false
    let myVote: VoteDirection?
    let isVoting: Bool
    let onVote: (VoteDirection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 14, weight: .semibold))

                Text(displayName)
                    .font(.subheadline.weight(.semibold))

                if isCloud {
                    Image(systemName: "icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.5))
                }

                Spacer()

                if isPending {
                    Text("\(votesNeeded) more needed")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.1), in: Capsule())
                }
            }

            if !noteBody.isEmpty {
                Text(noteBody)
                    .font(.subheadline)
                    .foregroundStyle(isPending ? .secondary : .primary)
            }

            HStack {
                Text(createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        onVote(.up)
                    } label: {
                        Label("\(upvotes)", systemImage: myVote == .up ? "arrow.up.circle.fill" : "arrow.up")
                            .font(.caption)
                            .foregroundStyle(myVote == .up ? AnyShapeStyle(Color.slopGreen) : AnyShapeStyle(.secondary))
                    }
                    .accessibilityLabel(myVote == .up ? "Remove upvote" : "Upvote")

                    Button {
                        onVote(.down)
                    } label: {
                        Label("\(downvotes)", systemImage: myVote == .down ? "arrow.down.circle.fill" : "arrow.down")
                            .font(.caption)
                            .foregroundStyle(myVote == .down ? AnyShapeStyle(Color.slopRed) : AnyShapeStyle(.secondary))
                    }
                    .accessibilityLabel(myVote == .down ? "Remove downvote" : "Downvote")
                }
                .buttonStyle(.plain)
                .disabled(isVoting)
                .sensoryFeedback(.selection, trigger: myVote)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isPending ? .secondary.opacity(0.05) : color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isPending ? .secondary.opacity(0.15) : color.opacity(0.2),
                    lineWidth: 1
                )
        )
        .opacity(isPending ? 0.7 : 1.0)
    }
}
