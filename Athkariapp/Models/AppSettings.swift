import Foundation
import SwiftData

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

/// Routine intensity level
enum RoutineIntensity: String, Codable, CaseIterable {
    case light = "light"
    case moderate = "moderate"
    case complete = "complete"

    var arabicName: String {
        switch self {
        case .light: return "أذكار الصباح والمساء"
        case .moderate: return "أذكار اليوم والليلة"
        case .complete: return "أذكار المسلم اليومية"
        }
    }

    var arabicDescription: String {
        switch self {
        case .light: return "الأذكار الأساسية اليومية فقط"
        case .moderate: return "أذكار الصباح والمساء"
        case .complete: return "أذكار النوم والاستيقاظ وكافة الأذكار"
        }
    }

    var icon: String {
        switch self {
        case .light: return "leaf.fill"
        case .moderate: return "flame.fill"
        case .complete: return "star.fill"
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
    var hapticsEnabled: Bool
    var notificationsEnabled: Bool
    var routineIntensity: String // RoutineIntensity rawValue
    var calculationMethod: String // CalculationMethod rawValue
    var locationPermissionState: String // LocationPermissionState rawValue
    var iCloudEnabled: Bool
    var fontSize: Double // Dynamic Type multiplier (not used, respects system)
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
        theme: AppTheme = .system,
        hapticsEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        routineIntensity: RoutineIntensity = .moderate,
        calculationMethod: CalculationMethod = .ummAlQura,
        locationPermissionState: LocationPermissionState = .notDetermined,
        iCloudEnabled: Bool = false,
        fontSize: Double = 1.0,
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
        self.theme = theme.rawValue
        self.hapticsEnabled = hapticsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.routineIntensity = routineIntensity.rawValue
        self.calculationMethod = calculationMethod.rawValue
        self.locationPermissionState = locationPermissionState.rawValue
        self.iCloudEnabled = iCloudEnabled
        self.fontSize = fontSize
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

    var intensity: RoutineIntensity {
        get { RoutineIntensity(rawValue: routineIntensity) ?? .moderate }
        set { routineIntensity = newValue.rawValue }
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
