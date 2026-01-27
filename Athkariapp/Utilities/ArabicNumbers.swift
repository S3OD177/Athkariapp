import Foundation

extension Int {
    /// Convert to English numerals (Pass-through for consistency)
    var arabicNumeral: String {
        return "\(self)"
    }
}

extension Double {
    /// Convert to English numerals
    var arabicNumeral: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension String {
    /// Ensures text is displayed correctly in RTL
    var rtlFormatted: String {
        "\u{200F}" + self // Right-to-left mark
    }
    
    /// Returns the string as is (English/Western digits)
    var arabicNumeral: String {
        return self
    }
}
