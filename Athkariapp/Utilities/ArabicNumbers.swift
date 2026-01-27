import Foundation

extension String {
    /// Ensures text is displayed correctly in RTL
    var rtlFormatted: String {
        "\u{200F}" + self // Right-to-left mark
    }
}
