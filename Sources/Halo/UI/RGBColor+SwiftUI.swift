import SwiftUI

extension RGBColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
