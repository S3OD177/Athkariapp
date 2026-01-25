import Foundation

extension Int {
    /// Convert to Arabic-Indic numerals
    var arabicNumeral: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    /// Convert to Arabic-Indic numerals
    var arabicNumeral: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension String {
    /// Ensures text is displayed correctly in RTL
    var rtlFormatted: String {
        "\u{200F}" + self // Right-to-left mark
    }
}
