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
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Text("Community Notes")
                    .font(DS.Typeface.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if isLoadingCloud {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading notes")
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
                    Text("Waiting for votes")
                        .font(DS.Typeface.meta.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.xs)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(pendingCloudNotes) { note in
                        CloudNoteCardView(note: note, isPending: true)
                    }
                }
            }
        }
        .task(id: restaurantID) { await loadCloudNotes() }
    }

    private func loadCloudNotes() async {
        // Sample data has no CloudKit records (and screenshot builds may be unsigned).
        guard !LaunchOptions.mockData else { return }
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
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label("No notes yet", systemImage: "text.bubble")
                .font(DS.Typeface.callout.weight(.semibold))
            Text("Spotted a Sysco truck out back, or a tip screen starting at 25%? Tell everyone.")
                .font(DS.Typeface.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: DS.Radius.card))
        .accessibilityElement(children: .combine)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                Label {
                    Text(displayName)
                        .font(DS.Typeface.callout.weight(.bold))
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }

                Spacer(minLength: 0)

                if isCloud {
                    Image(systemName: "icloud.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Synced")
                }
            }

            if !noteBody.isEmpty {
                Text(noteBody)
                    .font(DS.Typeface.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isPending {
                Text(votesNeeded == 1 ? "Needs 1 more vote to go public" : "Needs \(votesNeeded) more votes to go public")
                    .font(DS.Typeface.meta.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    timestamp
                    Spacer()
                    voteButtons
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    timestamp
                    voteButtons
                }
            }
        }
        .padding(DS.Spacing.l)
        .background(color.opacity(isPending ? 0.04 : 0.10), in: .rect(cornerRadius: DS.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .strokeBorder(
                    isPending ? AnyShapeStyle(.secondary) : AnyShapeStyle(color.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 1, dash: isPending ? [4, 3] : [])
                )
        }
        .accessibilityElement(children: .contain)
    }

    private var timestamp: some View {
        Text(createdAt, style: .relative)
            .font(DS.Typeface.meta)
            .foregroundStyle(.secondary)
    }

    private var voteButtons: some View {
        HStack(spacing: DS.Spacing.xs) {
            voteButton(.up, count: upvotes, symbol: "arrow.up", tint: DS.Palette.pickle, name: "Upvote")
            voteButton(.down, count: downvotes, symbol: "arrow.down", tint: DS.Palette.ketchup, name: "Downvote")
        }
        .disabled(isVoting)
        .sensoryFeedback(trigger: myVote) { _, new in
            new == .up ? .success : .selection
        }
    }

    private func voteButton(_ direction: VoteDirection, count: Int, symbol: String, tint: Color, name: String) -> some View {
        let isOn = myVote == direction
        return Button {
            onVote(direction)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isOn ? "\(symbol).circle.fill" : symbol)
                    .symbolEffect(.bounce, value: reduceMotion ? false : isOn)
                    .contentTransition(.symbolEffect(.replace))
                Text(count, format: .number)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
            }
            .font(DS.Typeface.callout.weight(.semibold))
            .foregroundStyle(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
            .padding(.horizontal, DS.Spacing.s)
            .frame(minWidth: DS.minHitTarget, minHeight: DS.minHitTarget)
            .background(isOn ? AnyShapeStyle(tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .snappySlop, value: count)
        .accessibilityLabel(name)
        .accessibilityValue(count == 1 ? "1 vote" : "\(count) votes")
        .accessibilityHint(isOn ? "Removes your vote" : "")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
