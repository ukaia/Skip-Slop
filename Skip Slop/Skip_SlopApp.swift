import SwiftUI
import SwiftData

@main
struct Skip_SlopApp: App {
    let chainDatabase = ChainDatabase()

    /// Unit tests run inside the app as host, often unsigned (no iCloud entitlement),
    /// where touching CKContainer would throw.
    private static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        // Screenshot/UI-test launch arguments (DEBUG only; see LaunchOptions).
        if LaunchOptions.showOnboarding {
            UserDefaults.standard.set(false, forKey: OnboardingView.seenKey)
        } else if LaunchOptions.skipOnboarding {
            UserDefaults.standard.set(true, forKey: OnboardingView.seenKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chainDatabase)
                #if DEBUG
                // Development environment only: production record types are deployed
                // from the CloudKit Dashboard, and every install writing seed records
                // to the production public database would be needless user writes.
                .task {
                    guard !Self.isHostingTests, !LaunchOptions.mockData else { return }
                    await CloudKitService.shared.initializeSchemaIfNeeded()
                }
                #endif
        }
        .modelContainer(Self.modelContainer)
    }

    /// Local store only. Notes and votes sync through `CloudKitService`'s public
    /// database; without `.none`, SwiftData turns on private-database sync because
    /// the app has the iCloud entitlement, and the store fails to load (CloudKit
    /// sync requires every attribute to be optional).
    private static let modelContainer: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: Restaurant.self, CommunityNote.self, configurations: configuration) {
            return container
        }
        // Last resort: keep the app usable with an in-memory store.
        let memory = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: Restaurant.self, CommunityNote.self, configurations: memory)
    }()
}
