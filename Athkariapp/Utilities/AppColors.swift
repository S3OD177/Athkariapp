import SwiftUI

typealias AppColors = Color

extension Color {
    // MARK: - App Palette
    static let appPrimary = Color(hex: "306ee8") // Match onboardingPrimary
    static let appSecondary = Color(red: 0.85, green: 0.75, blue: 0.5) // Warm gold
    
    // Fallback colors
    static let primaryFallback = Color(hex: "306ee8")
    static let secondaryFallback = Color(red: 0.9, green: 0.8, blue: 0.6) // Warm gold

    // Semantic colors
    static let success = Color.appPrimary
    static let warning = Color.onboardingPrimary
    static let error = Color.red

    // Text colors
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.5)
    
    // Status colors
    static let stateCompleted = Color.appPrimary
    static let statePartial = Color.onboardingPrimary.opacity(0.7)
    static let stateNotStarted = Color.gray
    
    // MARK: - Onboarding
    static let onboardingPrimary = Color(hex: "306ee8")
    static let onboardingBackground = Color(hex: "0F172A") 
    static let onboardingSurface = Color(hex: "1e293b")
    static let onboardingBorder = Color(hex: "ffffff").opacity(0.1) 
    static let onboardingCard = Color(hex: "1e293b")
    static let onboardingIconBg = Color(hex: "1e293b")
    static let textGray = Color(hex: "94a3b8") 

    // MARK: - Home (Design v1)
    static let homeBackground = Color(hex: "0F172A")
    static let homeCardBeige = Color(hex: "E6DCCA")
    static let homeAccentSoft = Color(hex: "D4A373")
    static let homeSurfaceDark = Color(hex: "1e293b")
    static let homeBeigeCard = Color(hex: "E6DCCA")
    
    // MARK: - Routine (Pastels)
    static let fajrBg = Color(hex: "ffedd5")
    static let fajrFg = Color(hex: "ea580c")
    static let dhuhrBg = Color(hex: "fffbeb")
    static let dhuhrFg = Color(hex: "d97706")
    static let asrBg = Color(hex: "fefce8")
    static let asrFg = Color(hex: "a16207")
    static let maghribBg = Color(hex: "fff1f2")
    static let maghribFg = Color(hex: "e11d48")
    static let ishaBg = Color(hex: "f1f5f9")
    static let ishaFg = Color(hex: "475569")
    static let morningBg = Color(hex: "eff6ff")
    static let morningFg = Color(hex: "2563eb")
    static let eveningBg = Color(hex: "eef2ff")
    static let eveningFg = Color(hex: "4f46e5")
    
    // MARK: - Session
    static let sessionPrimary = Color(hex: "dcb76e")
    static let sessionBackground = Color(hex: "0F172A")
    static let sessionSurface = Color(hex: "1e293b")
    
    // MARK: - Settings & Favorites
    static let settingsBackground = Color(hex: "0F172A")
    static let settingsSurface = Color(hex: "1e293b")
    static let separator = Color.white.opacity(0.1)
    static let favoritesPrimary = Color.white
    static let favoritesBg = Color(hex: "0F172A")

    // MARK: - Helpers
    /// Returns a color suitable for card backgrounds
    static var cardBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    /// Status colors based on session status
    static func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .completed: return .stateCompleted
        case .partial: return .statePartial
        case .notStarted: return .stateNotStarted
        }
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Global UI Components

struct AmbientBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top Left Glow
                Circle()
                    .fill(Color.onboardingPrimary.opacity(0.15))
                    .frame(width: geometry.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.1)
                
                // Bottom Right Glow
                Circle()
                    .fill(Color(hex: "4F46E5").opacity(0.1))
                    .frame(width: geometry.size.width * 0.7)
                    .blur(radius: 100)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.3)
                
                // Center Accent
                Circle()
                    .fill(Color(hex: "dcb76e").opacity(0.05))
                    .frame(width: geometry.size.width * 0.5)
                    .blur(radius: 60)
                    .offset(x: 0, y: geometry.size.height * 0.1)
            }
        }
        .ignoresSafeArea()
    }
}

struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var duration: Double = 0.1
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.easeInOut(duration: duration), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle {
        ScaleButtonStyle()
    }
    
    static func scale(amount: CGFloat = 0.96) -> ScaleButtonStyle {
        ScaleButtonStyle(scaleAmount: amount)
    }
}

