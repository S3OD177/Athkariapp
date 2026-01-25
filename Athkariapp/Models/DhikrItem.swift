import Foundation
import SwiftData

/// Source of the dhikr item
enum DhikrSource: String, Codable, CaseIterable {
    case daily = "daily"
    case hisn = "hisn"
    case userAdded = "user_added"
}

/// Category for daily athkar
enum DhikrCategory: String, Codable, CaseIterable {
    case morning = "morning"
    case evening = "evening"
    case afterPrayer = "after_prayer"
    case sleep = "sleep"
    case general = "general"

    var arabicName: String {
        switch self {
        case .morning: return "أذكار الصباح"
        case .evening: return "أذكار المساء"
        case .afterPrayer: return "أذكار بعد الصلاة"
        case .sleep: return "أذكار النوم"
        case .general: return "أذكار عامة"
        }
    }
}

/// Category for Hisn Al-Muslim
enum HisnCategory: String, Codable, CaseIterable {
    case waking = "waking"
    case sleeping = "sleeping"
    case prayer = "prayer"
    case quran = "quran"
    case travel = "travel"
    case food = "food"
    case home = "home"
    case illness = "illness"
    case protection = "protection"
    case forgiveness = "forgiveness"
    case gratitude = "gratitude"
    case distress = "distress"
    case misc = "misc"

    var arabicName: String {
        switch self {
        case .waking: return "الاستيقاظ"
        case .sleeping: return "النوم"
        case .prayer: return "الصلاة"
        case .quran: return "القرآن"
        case .travel: return "السفر"
        case .food: return "الطعام"
        case .home: return "المنزل"
        case .illness: return "المرض"
        case .protection: return "الحماية"
        case .forgiveness: return "الاستغفار"
        case .gratitude: return "الشكر"
        case .distress: return "الكرب"
        case .misc: return "متنوعة"
        }
    }

    var icon: String {
        switch self {
        case .waking: return "sunrise.fill"
        case .sleeping: return "moon.zzz.fill"
        case .prayer: return "hands.and.sparkles.fill"
        case .quran: return "book.fill"
        case .travel: return "car.fill"
        case .food: return "fork.knife"
        case .home: return "house.fill"
        case .illness: return "cross.case.fill"
        case .protection: return "shield.fill"
        case .forgiveness: return "heart.fill"
        case .gratitude: return "star.fill"
        case .distress: return "bolt.heart.fill"
        case .misc: return "ellipsis.circle.fill"
        }
    }
}

@Model
final class DhikrItem {
    @Attribute(.unique) var id: UUID
    var source: String // DhikrSource rawValue
    var title: String
    var category: String // DhikrCategory or HisnCategory rawValue
    var hisnCategory: String? // For hisn items
    var text: String
    var reference: String?
    var repeatCount: Int
    var orderIndex: Int
    var benefit: String?

    init(
        id: UUID = UUID(),
        source: DhikrSource,
        title: String,
        category: String,
        hisnCategory: HisnCategory? = nil,
        text: String,
        reference: String? = nil,
        repeatCount: Int = 1,
        orderIndex: Int = 0,
        benefit: String? = nil
    ) {
        self.id = id
        self.source = source.rawValue
        self.title = title
        self.category = category
        self.hisnCategory = hisnCategory?.rawValue
        self.text = text
        self.reference = reference
        self.repeatCount = repeatCount
        self.orderIndex = orderIndex
        self.benefit = benefit
    }

    var dhikrSource: DhikrSource {
        DhikrSource(rawValue: source) ?? .daily
    }

    var dhikrCategory: DhikrCategory? {
        DhikrCategory(rawValue: category)
    }

    var hisnCategoryEnum: HisnCategory? {
        guard let hisnCategory else { return nil }
        return HisnCategory(rawValue: hisnCategory)
    }
}
