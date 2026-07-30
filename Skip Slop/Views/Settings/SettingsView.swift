import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var restaurants: [Restaurant]
    @Query private var notes: [CommunityNote]

    var body: some View {
        List {
            Section("Rating Legend") {
                NavigationLink {
                    RatingLegendView()
                        .navigationTitle("Rating Guide")
                } label: {
                    Label("What do the colors mean?", systemImage: "paintpalette.fill")
                }
            }

            Section("Your Stats") {
                LabeledContent("Restaurants Visited", value: "\(restaurants.count)")
                LabeledContent("Community Notes", value: "\(notes.count)")
            }

            Section("About") {
                LabeledContent("Version", value: Self.appVersion)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Skip Slop")
                        .font(.headline)
                    Text("Tired of paying $30 for a microwaved Sysco meal? So are we. This app helps you find restaurants that serve real food — not frozen slop with fancy plating.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("In Development") {
                Label("Green+ Verification for Restaurants", systemImage: "checkmark.seal")
                Label("Photo Evidence Support", systemImage: "camera")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    /// Read from the bundle. This was hardcoded, so it drifted from the real build.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = info?["CFBundleVersion"] as? String, build != short else {
            return short
        }
        return "\(short) (\(build))"
    }
}
