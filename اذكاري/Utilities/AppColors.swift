import SwiftUI

/// App color palette
enum AppColors {
    // Primary colors
    static let primary = Color("Primary", bundle: nil)
    static let secondary = Color("Secondary", bundle: nil)

    // Fallback colors if assets not available
    static let primaryFallback = Color(red: 0.2, green: 0.5, blue: 0.4) // Teal green
    static let secondaryFallback = Color(red: 0.9, green: 0.8, blue: 0.6) // Warm gold

    // Semantic colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    // Background colors
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

    // Text colors
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)

    // Status colors
    static let completed = Color.green
    static let partial = Color.orange
    static let notStarted = Color.gray
}

extension Color {
    /// Returns the app's primary accent color
    static var appPrimary: Color {
        Color(red: 0.2, green: 0.55, blue: 0.45) // Islamic green/teal
    }

    /// Returns the app's secondary accent color
    static var appSecondary: Color {
        Color(red: 0.85, green: 0.75, blue: 0.5) // Warm gold
    }

    /// Returns a color suitable for card backgrounds
    static var cardBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    /// Status colors based on session status
    static func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .completed: return .green
        case .partial: return .orange
        case .notStarted: return .gray.opacity(0.5)
        }
    }
}
