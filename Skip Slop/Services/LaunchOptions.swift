import Foundation

/// Launch arguments for screenshots and UI tests. DEBUG builds only; Release
/// builds always see `false`.
///
/// - `-UITestScreenshots YES` — shorthand for `-skipOnboarding YES -mockData YES`
/// - `-skipOnboarding YES` — mark onboarding as seen
/// - `-showOnboarding YES` — show onboarding even if seen
/// - `-mockData YES` — sample restaurants around Austin, TX; no location, network
///   search, or CloudKit (notes and votes stay on the device)
/// - `-openDetail YES` — open the first restaurant's detail card
/// - `-openSettings YES` — open Settings
/// - `-noCloudKit YES` — real map and location, but notes and votes stay on the device
nonisolated enum LaunchOptions {
    static var screenshots: Bool { flag("UITestScreenshots") }
    static var skipOnboarding: Bool { flag("skipOnboarding") || screenshots }
    static var showOnboarding: Bool { flag("showOnboarding") }
    static var mockData: Bool { flag("mockData") || screenshots }
    static var openDetail: Bool { flag("openDetail") }
    static var openSettings: Bool { flag("openSettings") }
    /// No CloudKit at all; for unsigned UI-test builds, which lack the iCloud entitlement.
    static var noCloudKit: Bool { flag("noCloudKit") || mockData }

    private static func flag(_ name: String) -> Bool {
        #if DEBUG
        // `-name YES` lands in the argument domain; a bare `-name` is accepted too.
        UserDefaults.standard.bool(forKey: name) || ProcessInfo.processInfo.arguments.last == "-\(name)"
        #else
        false
        #endif
    }
}
