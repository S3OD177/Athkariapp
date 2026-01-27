import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

/// Theme preference
enum AppTheme: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var arabicName: String {
        switch self {
        case .system: return "تلقائي"
        case .light: return "فاتح"
        case .dark: return "داكن"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}


/// Prayer calculation method
enum CalculationMethod: String, Codable, CaseIterable {
    case ummAlQura = "umm_al_qura"
    case muslimWorldLeague = "muslim_world_league"
    case egyptian = "egyptian"
    case karachi = "karachi"
    case northAmerica = "north_america"

    var arabicName: String {
        switch self {
        case .ummAlQura: return "أم القرى"
        case .muslimWorldLeague: return "رابطة العالم الإسلامي"
        case .egyptian: return "الهيئة المصرية"
        case .karachi: return "جامعة كراتشي"
        case .northAmerica: return "أمريكا الشمالية"
        }
    }
}

/// Location permission state
enum LocationPermissionState: String, Codable {
    case notDetermined = "not_determined"
    case denied = "denied"
    case authorized = "authorized"

    var arabicName: String {
        switch self {
        case .notDetermined: return "غير محدد"
        case .denied: return "مرفوض"
        case .authorized: return "مسموح"
        }
    }
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var theme: String // AppTheme rawValue
    var userName: String
    var hapticsEnabled: Bool
    var notificationsEnabled: Bool
    var calculationMethod: String // CalculationMethod rawValue
    var locationPermissionState: String // LocationPermissionState rawValue
    var iCloudSyncEnabled: Bool
    var hapticIntensity: String // HapticIntensity rawValue
    var autoAdvance: Bool

    var lastLocationLatitude: Double?
    var lastLocationLongitude: Double?
    var lastLocationCity: String?
    var afterPrayerOffset: Int? // In minutes
    
    // Time Configuration (Hour 0-23)
    var wakingUpStart: Int
    var wakingUpEnd: Int
    var morningStart: Int
    var morningEnd: Int
    var eveningStart: Int
    var eveningEnd: Int
    var sleepStart: Int
    var sleepEnd: Int
    
    init(
        id: UUID = UUID(),
        userName: String = "",
        theme: AppTheme = .system,
        hapticsEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        calculationMethod: CalculationMethod = .ummAlQura,
        locationPermissionState: LocationPermissionState = .notDetermined,
        iCloudSyncEnabled: Bool = false,
        hapticIntensity: HapticIntensity = .medium,
        autoAdvance: Bool = false,
        afterPrayerOffset: Int = 15,
        wakingUpStart: Int = 3,
        wakingUpEnd: Int = 6,
        morningStart: Int = 6,
        morningEnd: Int = 11,
        eveningStart: Int = 15,
        eveningEnd: Int = 20,
        sleepStart: Int = 20,
        sleepEnd: Int = 3
    ) {
        self.id = id
        self.userName = userName
        self.theme = theme.rawValue
        self.hapticsEnabled = hapticsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.calculationMethod = calculationMethod.rawValue
        self.locationPermissionState = locationPermissionState.rawValue
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.hapticIntensity = hapticIntensity.rawValue
        self.autoAdvance = autoAdvance
        self.afterPrayerOffset = afterPrayerOffset
        self.wakingUpStart = wakingUpStart
        self.wakingUpEnd = wakingUpEnd
        self.morningStart = morningStart
        self.morningEnd = morningEnd
        self.eveningStart = eveningStart
        self.eveningEnd = eveningEnd
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
    }

    var appTheme: AppTheme {
        get { AppTheme(rawValue: theme) ?? .system }
        set { theme = newValue.rawValue }
    }


    var calculation: CalculationMethod {
        get { CalculationMethod(rawValue: calculationMethod) ?? .ummAlQura }
        set { calculationMethod = newValue.rawValue }
    }

    var locationState: LocationPermissionState {
        get { LocationPermissionState(rawValue: locationPermissionState) ?? .notDetermined }
        set { locationPermissionState = newValue.rawValue }
    }
}

enum HapticIntensity: String, Codable, CaseIterable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    
    var arabicName: String {
        switch self {
        case .light: return "خفيف"
        case .medium: return "متوسط"
        case .heavy: return "قوي"
        }
    }
    
    #if os(iOS)
    var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
    #endif
}
