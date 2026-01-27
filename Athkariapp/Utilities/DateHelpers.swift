import Foundation

extension Date {
    /// Start of day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of day for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Format time as HH:mm in Arabic locale
    func formatTimeArabic() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar@numbers=latn")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }

    /// Format date as full Arabic date
    func formatDateArabic() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar@numbers=latn")
        formatter.dateStyle = .full
        return formatter.string(from: self)
    }

    /// Get Arabic weekday name
    var arabicWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar@numbers=latn")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    /// Get Hijri date string
    func formatHijri() -> String {
        let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar@numbers=latn")
        formatter.calendar = islamicCalendar
        formatter.dateStyle = .long
        return formatter.string(from: self)
    }
}

extension Calendar {
    /// Returns Arabic calendar
    static var arabic: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ar@numbers=latn")
        return calendar
    }

    /// Returns Islamic (Umm Al-Qura) calendar
    static var islamic: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "ar@numbers=latn")
        return calendar
    }
}
