import SwiftUI
import CoreLocation

/// Three-page intro shown once: what the grades mean, location priming
/// (before the system prompt), and community notes. Skippable at any point.
struct OnboardingView: View {
    static let seenKey = "hasSeenOnboarding"

    let onFinish: () -> Void

    @State private var page = Page.grades
    @State private var locationManager = LocationManager()
    @State private var askedForLocation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Page: Int, CaseIterable {
        case grades, location, notes
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .font(DS.Typeface.headline)
                    .frame(minWidth: DS.minHitTarget, minHeight: DS.minHitTarget)
                    .accessibilityHint("Skips the intro and opens the map")
            }
            .padding(.horizontal, DS.Spacing.l)

            TabView(selection: $page) {
                gradesPage.tag(Page.grades)
                locationPage.tag(Page.location)
                notesPage.tag(Page.notes)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            actions
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.l)
        }
        .sensoryFeedback(.selection, trigger: page)
        .onChange(of: locationManager.authorizationStatus) { _, status in
            // The system prompt was answered; move on either way.
            if askedForLocation, status != .notDetermined, page == .location {
                advance()
            }
        }
    }

    // MARK: - Pages

    private var gradesPage: some View {
        OnboardingPage(
            title: "Grade the slop before you eat it",
            message: "Every restaurant gets a grade. A means real food. F means Sysco trucks and microwaves. F− means you also paid steakhouse prices for it."
        ) {
            PlacardFan(isActive: page == .grades)
        }
    }

    private var locationPage: some View {
        OnboardingPage(
            title: "See what's around you",
            message: "Skip Slop uses your location to grade restaurants nearby. It stays on your device. You can always search a city or zip code instead."
        ) {
            Image(systemName: "location.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(DS.Palette.ink)
                .frame(width: 140, height: 140)
                .background(DS.accent, in: .rect(cornerRadius: DS.Radius.hero))
                .symbolEffect(.pulse, isActive: page == .location && !reduceMotion)
                .accessibilityHidden(true)
        }
    }

    private var notesPage: some View {
        OnboardingPage(
            title: "Snitch on the slop",
            message: "Saw a Sysco truck out back? Paid $30 for a burger? Leave a note. Notes go public once the community upvotes them."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Label("Sysco Verified", systemImage: NoteType.syscoVerified.icon)
                    .font(DS.Typeface.callout.weight(.bold))
                    .foregroundStyle(NoteType.syscoVerified.color)
                Text("Truck was unloading frozen fries at 7 am.")
                    .font(DS.Typeface.body)
                HStack(spacing: DS.Spacing.m) {
                    Label("12", systemImage: "arrow.up.circle.fill").foregroundStyle(DS.Palette.pickle)
                    Label("1", systemImage: "arrow.down").foregroundStyle(.secondary)
                }
                .font(DS.Typeface.callout.weight(.semibold))
            }
            .padding(DS.Spacing.l)
            .frame(maxWidth: 300, alignment: .leading)
            .background(NoteType.syscoVerified.color.opacity(0.1), in: .rect(cornerRadius: DS.Radius.card))
            .rotationEffect(.degrees(-3))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Example note: Sysco Verified. Truck was unloading frozen fries at 7 am. 12 upvotes.")
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: DS.Spacing.s) {
            switch page {
            case .grades:
                primaryButton("Next", action: advance)
            case .location:
                if locationManager.authorizationStatus == .notDetermined {
                    primaryButton("Allow Location") {
                        askedForLocation = true
                        locationManager.requestPermission()
                    }
                    Button("Not Now", action: advance)
                        .font(DS.Typeface.headline)
                        .frame(minHeight: DS.minHitTarget)
                } else {
                    primaryButton("Next", action: advance)
                }
            case .notes:
                primaryButton("Start Exploring", action: onFinish)
            }
        }
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typeface.headline)
                .foregroundStyle(DS.onAccent)
                .frame(maxWidth: .infinity, minHeight: DS.minHitTarget)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private func advance() {
        guard let next = Page(rawValue: page.rawValue + 1) else {
            onFinish()
            return
        }
        withAnimation(reduceMotion ? nil : .snappySlop) { page = next }
    }
}

// MARK: - Page layout

private struct OnboardingPage<Art: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let art: Art

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                art
                    .frame(maxWidth: .infinity, minHeight: 220)
                Text(title)
                    .font(DS.Typeface.display)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(DS.Typeface.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Three placards fanned like cards in a hand; they deal in when the page shows.
private struct PlacardFan: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scaledSide: CGFloat = 104
    @State private var dealt = false

    /// Capped so three fanned cards still fit at the largest text sizes.
    private var side: CGFloat { min(scaledSide, 150) }
    /// Reduce Motion: cards start in place and only fade in.
    private var spread: Bool { dealt || reduceMotion }

    private struct Card: Identifiable {
        let rating: SlopRating
        let angle: Double
        let x: CGFloat
        var id: SlopRating { rating }
    }

    private let cards = [
        Card(rating: .green, angle: -14, x: -0.75),
        Card(rating: .yellow, angle: 0, x: 0),
        Card(rating: .red, angle: 14, x: 0.75),
    ]

    var body: some View {
        ZStack {
            ForEach(cards) { card in
                VStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: card.rating.symbol)
                        .font(.title3.weight(.bold))
                    Text(card.rating.grade)
                        .font(.system(size: side * 0.42, weight: .black, design: .rounded))
                    Text(card.rating.name)
                        .font(DS.Typeface.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(DS.Palette.ink)
                .padding(DS.Spacing.s)
                .frame(width: side, height: side * 1.3)
                .background(card.rating.color, in: .rect(cornerRadius: DS.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .inset(by: 5)
                        .strokeBorder(DS.Palette.ink.opacity(0.45), lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                .rotationEffect(.degrees(spread ? card.angle : 0), anchor: .bottom)
                .offset(x: spread ? card.x * side : 0, y: spread ? 0 : 30)
                .opacity(dealt ? 1 : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example grades: A, Real Food. B, Some Slop. F, Sysco Slop.")
        .onChange(of: isActive, initial: true) { _, active in
            guard active, !dealt else { return }
            withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(duration: 0.6, bounce: 0.35).delay(0.15)) {
                dealt = true
            }
        }
    }
}

#Preview {
    OnboardingView {}
}
