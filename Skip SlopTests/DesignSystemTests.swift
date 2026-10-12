import SwiftUI
import UIKit
import Testing
@testable import Skip_Slop

@Suite("Design system")
struct DesignSystemTests {
    @Test func everyRatingHasAUniqueGradeAndSymbol() {
        let ratings = SlopRating.allCases
        #expect(Set(ratings.map(\.grade)).count == ratings.count)
        #expect(Set(ratings.map(\.symbol)).count == ratings.count)
        #expect(Set(ratings.map(\.name)).count == ratings.count)
    }

    @Test(arguments: SlopRating.allCases)
    func symbolExists(_ rating: SlopRating) {
        #expect(UIImage(systemName: rating.symbol) != nil, "Missing SF Symbol \(rating.symbol)")
    }

    @Test(arguments: SlopRating.allCases)
    func accessibilityLabelSpeaksGradeAndName(_ rating: SlopRating) {
        #expect(rating.accessibilityLabel.contains(rating.name))
        #expect(!rating.accessibilityLabel.contains("−"), "Minus sign should be spoken as a word")
    }

    /// Ink on every rating fill must meet WCAG AA (4.5:1) in all four appearances.
    @Test(arguments: SlopRating.allCases)
    func inkOnRatingFillIsReadable(_ rating: SlopRating) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection { traits in
                    traits.userInterfaceStyle = style
                    traits.accessibilityContrast = contrast
                }
                let fill = UIColor(rating.color).resolvedColor(with: traits)
                let ink = UIColor(DS.Palette.ink).resolvedColor(with: traits)
                let ratio = contrastRatio(fill, ink)
                #expect(ratio >= 4.5, "\(rating) \(style.rawValue)/\(contrast.rawValue): \(ratio)")
            }
        }
    }

    @Test func meterCoversEveryGradedRating() {
        #expect(SlopRating.meterCases.count == SlopRating.allCases.count - 1)
        #expect(SlopRating.grey.meterIndex == nil)
    }

    @Test func launchOptionsAreOffByDefault() {
        #expect(!LaunchOptions.mockData)
        #expect(!LaunchOptions.openDetail)
        #expect(!LaunchOptions.openSettings)
    }

    private func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
