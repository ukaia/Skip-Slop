import SwiftUI
import UIKit

/// Skip Slop design tokens.
///
/// The visual idea: a health-inspection placard taped to a restaurant window.
/// Ratings read as letter grades (A+ … F−) on condiment-colored placards, set in
/// heavy SF Rounded. Everything around the placards stays native Liquid Glass so
/// the grades are the loudest thing on screen.
nonisolated enum DS {

    // MARK: - Color

    /// Condiment palette. Every color has light, dark, and increased-contrast
    /// variants resolved by trait, so callers never branch on color scheme.
    /// Light variants clear 4.5:1 against white; dark variants clear 4.5:1
    /// against black and against `ink` when used as a fill.
    nonisolated enum Palette {
        /// Fresh herbs — real, local food.
        static let basil   = Color.dynamic(light: 0x13723F, dark: 0x4FD18B, lightHC: 0x0A5A2F, darkHC: 0x8AF5B9)
        /// Real food.
        static let pickle  = Color.dynamic(light: 0x3F7A12, dark: 0x9AD94A, lightHC: 0x2E5C0B, darkHC: 0xC4F584)
        /// Some slop. Also the brand accent.
        static let mustard = Color.dynamic(light: 0x8F6200, dark: 0xFFC93C, lightHC: 0x6E4B00, darkHC: 0xFFDC7A)
        /// Low grade, deep-fried.
        static let fryer   = Color.dynamic(light: 0xB24A00, dark: 0xFF8A3D, lightHC: 0x8E3A00, darkHC: 0xFFAD72)
        /// Sysco slop.
        static let ketchup = Color.dynamic(light: 0xC21F17, dark: 0xFF5A4F, lightHC: 0x9E140D, darkHC: 0xFF8A80)
        /// Sysco slop at steakhouse prices.
        static let beet    = Color.dynamic(light: 0x9C1A5C, dark: 0xEC6AAE, lightHC: 0x7D0E47, darkHC: 0xF79BCB)
        /// Cafeteria tray — fast food, not rated.
        static let tray    = Color.dynamic(light: 0x5B6470, dark: 0x9BA3AE, lightHC: 0x434B56, darkHC: 0xC9CED5)

        /// Text and glyphs drawn on top of a palette fill.
        static let ink     = Color.dynamic(light: 0xFFFFFF, dark: 0x1C1612, lightHC: 0xFFFFFF, darkHC: 0x000000)
    }

    static let accent = Palette.mustard
    static let onAccent = Palette.ink
    /// Community-note contestation; deliberately outside the rating palette.
    static let contested = Color.dynamic(light: 0x1F5FBF, dark: 0x6FA8FF, lightHC: 0x124799, darkHC: 0xA3C7FF)

    // MARK: - Typography

    /// Text styles only, so everything follows Dynamic Type. Rounded heavy weights
    /// carry the brand; body copy stays default SF for legibility.
    nonisolated enum Typeface {
        static let display  = Font.system(.largeTitle, design: .rounded, weight: .black)
        static let title    = Font.system(.title2, design: .rounded, weight: .heavy)
        static let headline = Font.system(.headline, design: .rounded, weight: .bold)
        static let grade    = Font.system(.title3, design: .rounded, weight: .black)
        static let body     = Font.body
        static let callout  = Font.callout
        static let meta     = Font.footnote
        static let caption  = Font.caption.weight(.medium)
    }

    // MARK: - Layout

    nonisolated enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    nonisolated enum Radius {
        /// Small placards (pins, list badges).
        static let placard: CGFloat = 10
        /// Cards inside sheets; concentric with the sheet's own corner.
        static let card: CGFloat = 22
        /// The big detail placard.
        static let hero: CGFloat = 28
    }

    /// Apple HIG minimum tappable size.
    static let minHitTarget: CGFloat = 44
}

// MARK: - Color helpers

extension Color {
    /// A color resolved per trait collection: light/dark plus increased-contrast variants.
    nonisolated static func dynamic(light: UInt32, dark: UInt32, lightHC: UInt32? = nil, darkHC: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let highContrast = traits.accessibilityContrast == .high
            let hex: UInt32 = switch (traits.userInterfaceStyle == .dark, highContrast) {
            case (true, true):   darkHC ?? dark
            case (true, false):  dark
            case (false, true):  lightHC ?? light
            case (false, false): light
            }
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Motion

extension Animation {
    /// The house spring: quick, slightly bouncy, never sloppy. Callers swap it for
    /// a fade or `nil` when Reduce Motion is on.
    static let snappySlop = Animation.spring(duration: 0.4, bounce: 0.25)
}
