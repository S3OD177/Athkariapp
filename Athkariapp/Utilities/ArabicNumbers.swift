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
    
    /// Converts all ASCII digits in the string to Arabic-Indic digits
    var arabicNumeral: String {
        let arabicDigits = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        var result = self
        for (i, digit) in arabicDigits.enumerated() {
            result = result.replacingOccurrences(of: "\(i)", with: digit)
        }
        return result
    }
}
