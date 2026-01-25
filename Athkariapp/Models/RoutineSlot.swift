import Foundation
import SwiftData

/// Time slots for daily routines
enum SlotKey: String, Codable, CaseIterable {
    case morning = "morning"
    case afterFajr = "after_fajr"
    case afterDhuhr = "after_dhuhr"
    case afterAsr = "after_asr"
    case afterMaghrib = "after_maghrib"
    case afterIsha = "after_isha"
    case evening = "evening"
    case sleep = "sleep"

    var arabicName: String {
        switch self {
        case .morning: return "أذكار الصباح"
        case .afterFajr: return "بعد الفجر"
        case .afterDhuhr: return "بعد الظهر"
        case .afterAsr: return "بعد العصر"
        case .afterMaghrib: return "بعد المغرب"
        case .afterIsha: return "بعد العشاء"
        case .evening: return "أذكار المساء"
        case .sleep: return "أذكار النوم"
        }
    }

    var shortName: String {
        switch self {
        case .morning: return "الصباح"
        case .afterFajr: return "الفجر"
        case .afterDhuhr: return "الظهر"
        case .afterAsr: return "العصر"
        case .afterMaghrib: return "المغرب"
        case .afterIsha: return "العشاء"
        case .evening: return "المساء"
        case .sleep: return "النوم"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afterFajr: return "sunrise.fill"
        case .afterDhuhr: return "sun.max.fill"
        case .afterAsr: return "sun.haze.fill"
        case .afterMaghrib: return "sunset.fill"
        case .afterIsha: return "moon.fill"
        case .evening: return "sunset.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .morning: return 0
        case .afterFajr: return 1
        case .afterDhuhr: return 2
        case .afterAsr: return 3
        case .afterMaghrib: return 4
        case .afterIsha: return 5
        case .evening: return 6
        case .sleep: return 7
        }
    }

    var isAfterPrayer: Bool {
        switch self {
        case .afterFajr, .afterDhuhr, .afterAsr, .afterMaghrib, .afterIsha:
            return true
        default:
            return false
        }
    }

    /// Maps to DhikrCategory for filtering
    var dhikrCategory: DhikrCategory {
        switch self {
        case .morning: return .morning
        case .afterFajr, .afterDhuhr, .afterAsr, .afterMaghrib, .afterIsha:
            return .afterPrayer
        case .evening: return .evening
        case .sleep: return .sleep
        }
    }
}

@Model
final class RoutineSlot {
    @Attribute(.unique) var id: UUID
    var key: String // SlotKey rawValue
    var displayNameArabic: String
    var sortOrder: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        key: SlotKey,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key.rawValue
        self.displayNameArabic = key.arabicName
        self.sortOrder = key.sortOrder
        self.isEnabled = isEnabled
    }

    var slotKey: SlotKey? {
        SlotKey(rawValue: key)
    }
}
