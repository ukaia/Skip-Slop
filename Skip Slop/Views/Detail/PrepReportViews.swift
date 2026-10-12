import SwiftUI

// MARK: - Section on the detail card

/// "How is the food made here?" with the three answers, the community tally,
/// and evidence notes from other diners.
struct PrepReportSection: View {
    let placeKey: String
    let isGraded: Bool
    let onReport: (PrepVerdict) -> Void

    @State private var noteToFlag: PrepReport?
    private var store: PrepReportStore { .shared }

    var body: some View {
        let rollup = store.rollup(for: placeKey) ?? .empty
        let mine = store.myReport(for: placeKey)
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("How is the food made here?")
                    .font(DS.Typeface.headline)
                    .accessibilityAddTraits(.isHeader)
                if !isGraded && mine == nil {
                    Text("Be one of the first to say. Five reports make a community grade.")
                        .font(DS.Typeface.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let mine {
                Label {
                    Text("Your report: \(mine.verdict.title)")
                        .font(DS.Typeface.callout.weight(.semibold))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Palette.pickle)
                }
                .accessibilityElement(children: .combine)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.s) { verdictButtons(selected: mine?.verdict) }
                VStack(alignment: .leading, spacing: DS.Spacing.s) { verdictButtons(selected: mine?.verdict) }
            }

            tally(rollup)

            let notes = store.notes(for: placeKey)
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    ForEach(notes) { note in
                        PrepNoteCard(
                            report: note,
                            isMine: note.reporterID == store.reporterID,
                            isFlagged: store.flaggedByMe.contains(note.id),
                            onFlag: { noteToFlag = note }
                        )
                    }
                }
            }
        }
        .padding(DS.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: .rect(cornerRadius: DS.Radius.card))
        .confirmationDialog(
            "Report this note?",
            isPresented: Binding(get: { noteToFlag != nil }, set: { if !$0 { noteToFlag = nil } }),
            titleVisibility: .visible,
            presenting: noteToFlag
        ) { note in
            Button("Report Note", role: .destructive) {
                Task { await store.flag(note) }
            }
        } message: { _ in
            Text("Report notes that are abusive, off-topic, spam, or share personal information. Notes reported by several people are hidden.")
        }
    }

    @ViewBuilder
    private func verdictButtons(selected: PrepVerdict?) -> some View {
        ForEach(PrepVerdict.allCases) { verdict in
            Button {
                onReport(verdict)
            } label: {
                Label(verdict.title, systemImage: verdict.symbol)
                    .font(DS.Typeface.callout.weight(.semibold))
                    .lineLimit(1)
                    .frame(minHeight: DS.minHitTarget)
                    .padding(.horizontal, DS.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(selected == verdict ? DS.accent : nil)
            .accessibilityAddTraits(selected == verdict ? .isSelected : [])
            .accessibilityHint("Report how the food is made here")
        }
    }

    @ViewBuilder
    private func tally(_ rollup: CommunityRollup) -> some View {
        if rollup.counted > 0 || rollup.unsureCount > 0 {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                let count = Text(rollup.counted == 1 ? "1 report" : "\(rollup.counted) reports").fontWeight(.semibold)
                let share = rollup.counted > 0 ? " · \(rollup.scratchPercent)% say made from scratch" : ""
                Text("\(count)\(share)")
                    .font(DS.Typeface.callout)
                if !rollup.qualifies {
                    Text(rollup.reportsNeeded == 1
                         ? "1 more report needed for a community grade."
                         : "\(max(rollup.reportsNeeded, 1)) more reports needed for a community grade.")
                        .font(DS.Typeface.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// One diner's evidence note, with a Report button for anyone else.
private struct PrepNoteCard: View {
    let report: PrepReport
    let isMine: Bool
    let isFlagged: Bool
    let onFlag: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label(report.verdict.title, systemImage: report.verdict.symbol)
                    .font(DS.Typeface.callout.weight(.bold))
                if let evidence = report.evidence {
                    Text("· \(evidence.title)")
                        .font(DS.Typeface.meta)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(report.note)
                .font(DS.Typeface.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(report.updatedAt, style: .relative)
                    .font(DS.Typeface.meta)
                    .foregroundStyle(.secondary)
                Spacer()
                if isMine {
                    Text("Your note")
                        .font(DS.Typeface.meta)
                        .foregroundStyle(.secondary)
                } else if isFlagged {
                    Label("Reported", systemImage: "flag.fill")
                        .font(DS.Typeface.meta.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Button(action: onFlag) {
                        Label("Report", systemImage: "flag")
                            .font(DS.Typeface.meta.weight(.semibold))
                            .frame(minWidth: DS.minHitTarget, minHeight: DS.minHitTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Report note")
                    .accessibilityHint("Flags this note as abusive or off-topic")
                }
            }
        }
        .padding(DS.Spacing.m)
        .background(.background, in: .rect(cornerRadius: DS.Radius.placard))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Report form

/// Files or edits the current user's prep report for a place.
struct ReportPrepView: View {
    let placeName: String
    let placeKey: String
    let chainSlug: String?
    let initialVerdict: PrepVerdict

    @Environment(\.dismiss) private var dismiss
    @State private var verdict: PrepVerdict = .scratch
    @State private var evidence: PrepEvidence?
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @State private var didLoad = false

    private var store: PrepReportStore { .shared }
    private var isEditing: Bool { store.myReport(for: placeKey) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("How is the food made here?", selection: $verdict) {
                        ForEach(PrepVerdict.allCases) { verdict in
                            Text(verdict.title).tag(verdict)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("How is the food made at \(placeName)?")
                        .textCase(nil)
                        .font(DS.Typeface.headline)
                        .foregroundStyle(.primary)
                }

                if verdict != .unsure {
                    Section {
                        Picker("Evidence", selection: $evidence) {
                            Text("Skip").tag(PrepEvidence?.none)
                            ForEach(PrepEvidence.options(for: verdict)) { option in
                                Label(option.title, systemImage: option.symbol).tag(PrepEvidence?.some(option))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("What's that based on? (optional)")
                    } footer: {
                        Text("Firsthand evidence counts more toward the community grade.")
                    }
                }

                Section {
                    TextField("e.g. the menu says the tortillas are made in house", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityLabel("Note")
                } header: {
                    Text("Anything to add? (optional)")
                } footer: {
                    Text("Notes are public and filtered for abuse. Stick to how the food is made. One report per person per place; you can change yours any time.")
                }
            }
            .navigationTitle(isEditing ? "Edit Your Report" : "Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Submit Report") {
                        Task { await submit() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || didSave)
                }
            }
            .onChange(of: verdict) { _, new in
                if let current = evidence, !PrepEvidence.options(for: new).contains(current) {
                    evidence = nil
                }
            }
            .alert("Report Not Saved", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sensoryFeedback(.success, trigger: didSave)
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                verdict = initialVerdict
                if let mine = store.myReport(for: placeKey) {
                    evidence = mine.verdict == initialVerdict ? mine.evidence : nil
                    note = mine.note
                }
            }
        }
    }

    private func submit() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.submit(placeKey: placeKey, chainSlug: chainSlug, verdict: verdict, evidence: evidence, note: note)
            didSave = true
            try? await Task.sleep(for: .milliseconds(150))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Why this grade

/// The evidence behind a grade: basis, confidence, and source links.
struct WhyThisGradeView: View {
    let placeName: String
    let assessment: GradeAssessment

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: DS.Spacing.m) {
                        SlopRatingBadge(rating: assessment.rating, size: .tile, style: PlacardStyle(assessment))
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(assessment.rating.name).font(DS.Typeface.headline)
                            Text(assessment.label).font(DS.Typeface.callout).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                switch assessment.kind {
                case .cited(let confidence):
                    if let basis = assessment.basis {
                        Section("What we found") {
                            Text(basis).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Section {
                        ForEach(assessment.sources, id: \.self) { source in
                            Link(destination: source.url) {
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(source.title)
                                        .font(DS.Typeface.callout.weight(.semibold))
                                        .multilineTextAlignment(.leading)
                                    Text("\(source.tierName) · \(source.url.host() ?? "")")
                                        .font(DS.Typeface.meta)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityHint("Opens in Safari")
                        }
                    } header: {
                        Text(assessment.sources.count == 1 ? "Source" : "Sources")
                    } footer: {
                        Text(Self.confidenceExplanation(confidence))
                    }
                case .community(let reports):
                    Section("From the community") {
                        Text("Graded from \(reports) diner reports on whether the food is made from scratch or reheated. Firsthand evidence counts more, new accounts count less, and lone outliers are damped.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .notGraded:
                    Section {
                        Text("No evidence yet. We don't guess.")
                    }
                }

                if let supplement = assessment.supplement, supplement.counted > 0, !assessment.isCommunity {
                    Section("Community reports") {
                        Text("\(supplement.counted) reports · \(supplement.scratchPercent)% say made from scratch")
                    }
                }

                Section {
                    Text("Grades describe how the food is made, from A+ (from scratch with local ingredients) to F− (distributor meals reheated). They're based on public evidence and diner reports, not health inspections.")
                        .font(DS.Typeface.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Why this grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static func confidenceExplanation(_ confidence: GradeConfidence) -> String {
        switch confidence {
        case .high: "High confidence: several sources agree, including independent reporting or insider accounts."
        case .medium: "Medium confidence: a couple of agreeing sources, or one company or press source."
        case .low: "Low confidence: a single insider or diner account. Your reports can change this grade."
        }
    }
}
