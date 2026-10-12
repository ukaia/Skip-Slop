import SwiftUI
import SwiftData

struct SettingsView: View {
    static let privacyPolicyURL = URL(string: "https://github.com/ukaia/Skip-Slop/blob/main/PRIVACY.md")!

    @Environment(\.dismiss) private var dismiss
    @AppStorage(OnboardingView.seenKey) private var hasSeenOnboarding = true
    @Query private var notes: [CommunityNote]

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    RatingGuideScreen()
                } label: {
                    HStack(spacing: DS.Spacing.m) {
                        Label("Rating Guide", systemImage: "list.bullet.rectangle.portrait")
                        Spacer(minLength: 0)
                        HStack(spacing: -6) {
                            ForEach([SlopRating.green, .yellow, .red], id: \.self) { rating in
                                Image(systemName: rating.symbol)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(DS.Palette.ink)
                                    .frame(width: 26, height: 26)
                                    .background(rating.color, in: .circle)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
            } footer: {
                Text("What A+ through F− mean, and where grades come from.")
            }

            Section("Your Notes") {
                LabeledContent("Notes posted", value: notes.count, format: .number)
            }

            Section {
                Button {
                    hasSeenOnboarding = false
                    dismiss()
                } label: {
                    Label("Replay Intro", systemImage: "play.circle")
                }
            }

            Section {
                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                .accessibilityHint("Opens in Safari")

                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Label("Acknowledgements", systemImage: "heart.text.square")
                }

                LabeledContent("Version", value: versionString)
            } header: {
                Text("About")
            } footer: {
                Text("Tired of paying $30 for a microwaved Sysco meal? So are we. Skip Slop points you to restaurants that cook real food.")
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section {
                credit("Maps and places", "Apple MapKit. Map data © Apple and its data providers.")
                credit("Community notes", "Stored in Apple CloudKit. No accounts, no tracking.")
                credit("Symbols", "SF Symbols by Apple.")
            }
            Section {
                credit("Grades", "Chain grades come from cited public evidence on how each chain prepares its food: company filings and websites, news and trade reporting, and former employees' accounts. Community grades come from diner reports. Grades are opinions, not inspection results.")
                credit("Chain names", "OpenStreetMap name-suggestion-index and Wikipedia.")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func credit(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title).font(DS.Typeface.headline)
            Text(detail)
                .font(DS.Typeface.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DS.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
