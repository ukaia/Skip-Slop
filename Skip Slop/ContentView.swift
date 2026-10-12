import SwiftUI

/// Root: onboarding until it's been seen, then the map-first explore screen.
struct ContentView: View {
    @AppStorage(OnboardingView.seenKey) private var hasSeenOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                MapContainerView()
                    .transition(.opacity)
            } else {
                OnboardingView { hasSeenOnboarding = true }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasSeenOnboarding)
        .tint(DS.accent)
    }
}
