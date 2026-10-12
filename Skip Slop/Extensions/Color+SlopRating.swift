import SwiftUI

/// Rating colors by rating name. Backed by the condiment palette in `DS.Palette`,
/// so they adapt to dark mode and Increase Contrast.
nonisolated extension ShapeStyle where Self == Color {
    static var slopGreenPlus: Color { DS.Palette.basil }
    static var slopGreen: Color { DS.Palette.pickle }
    static var slopYellow: Color { DS.Palette.mustard }
    static var slopOrange: Color { DS.Palette.fryer }
    static var slopRed: Color { DS.Palette.ketchup }
    static var slopRedMinus: Color { DS.Palette.beet }
    static var slopGrey: Color { DS.Palette.tray }
}
