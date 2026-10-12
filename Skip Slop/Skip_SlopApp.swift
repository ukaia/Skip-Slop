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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chainDatabase)
                .task {
                    guard !Self.isHostingTests else { return }
                    await CloudKitService.shared.initializeSchemaIfNeeded()
                }
        }
        .modelContainer(for: [Restaurant.self, CommunityNote.self])
    }
}
