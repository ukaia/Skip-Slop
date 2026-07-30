import SwiftUI
import UIKit

/// The rating scale is the only chromatic language in the app, so it has to survive both
/// map styles. These were flat RGB literals with no dark variants — `slopRedMinus` at
/// (0.60, 0.08, 0.08) and `slopGreenPlus` at (0.18, 0.49, 0.20) are both near-black, and
/// pins wearing them disappeared against a dark map at night.
extension ShapeStyle where Self == Color {
    static var slopGreenPlus: Color {
        .slopDynamic(light: (0.13, 0.44, 0.17), dark: (0.42, 0.80, 0.47))
    }

    static var slopGreen: Color {
        .slopDynamic(light: (0.20, 0.59, 0.24), dark: (0.48, 0.86, 0.52))
    }

    static var slopYellow: Color {
        .slopDynamic(light: (0.85, 0.57, 0.06), dark: (1.00, 0.78, 0.32))
    }

    static var slopOrange: Color {
        .slopDynamic(light: (0.87, 0.39, 0.00), dark: (1.00, 0.60, 0.24))
    }

    static var slopRed: Color {
        .slopDynamic(light: (0.78, 0.16, 0.16), dark: (0.98, 0.42, 0.40))
    }

    static var slopRedMinus: Color {
        .slopDynamic(light: (0.58, 0.07, 0.07), dark: (0.90, 0.30, 0.30))
    }

    static var slopGrey: Color {
        .slopDynamic(light: (0.42, 0.42, 0.44), dark: (0.64, 0.64, 0.67))
    }
}

private extension Color {
    typealias RGB = (r: Double, g: Double, b: Double)

    static func slopDynamic(light: RGB, dark: RGB) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        })
    }
}
