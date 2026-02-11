import Foundation

struct AthkariWidgetSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let appGroupIdentifier = "group.com.Athkariapp.shared"
    static let storageKey = "athkari.widget.snapshot.v1"
    static let homeWidgetKind = "AthkariHomeWidget"

    struct SessionContent: Codable, Equatable, Sendable {
        let slotKey: String
        let title: String
        let subtitle: String
        let currentCount: Int
        let targetCount: Int
        let progress: Double
        let heroLabel: String?
        let heroPrimaryLine: String?
        let heroSecondaryLine: String?
        let completionText: String?
        let nextTitle: String?
        let windowEndDate: Date?
        let iconSystemName: String?
        let routeURL: String

        var normalizedProgress: Double {
            min(max(progress, 0), 1)
        }
    }

    struct PrayerContent: Codable, Equatable, Sendable {
        let label: String
        let nextPrayerName: String
        let nextPrayerDate: Date?
        let windowEndDate: Date?
        let slotKey: String?
        let routeURL: String
    }

    struct FallbackContent: Codable, Equatable, Sendable {
        let title: String
        let subtitle: String
        let routeURL: String
    }

    enum ActiveContent: Equatable, Sendable {
        case session(SessionContent)
        case prayer(PrayerContent)
        case fallback(FallbackContent)
    }

    var version: Int
    var generatedAt: Date
    var session: SessionContent?
    var prayer: PrayerContent?
    var fallback: FallbackContent

    var activeContent: ActiveContent {
        if let session {
            return .session(session)
        }
        if let prayer {
            return .prayer(prayer)
        }
        return .fallback(fallback)
    }

    var effectiveRouteURL: String {
        switch activeContent {
        case .session(let session):
            return session.routeURL
        case .prayer(let prayer):
            return prayer.routeURL
        case .fallback(let fallback):
            return fallback.routeURL
        }
    }

    static func fallbackSnapshot(generatedAt: Date = Date()) -> AthkariWidgetSnapshot {
        AthkariWidgetSnapshot(
            version: currentVersion,
            generatedAt: generatedAt,
            session: nil,
            prayer: nil,
            fallback: FallbackContent(
                title: "أذكاري",
                subtitle: "افتح التطبيق لمتابعة أذكارك",
                routeURL: AthkariWidgetRoutes.home
            )
        )
    }

    static func decode(from data: Data?) -> AthkariWidgetSnapshot {
        guard let data else {
            return fallbackSnapshot()
        }

        do {
            let snapshot = try JSONDecoder().decode(AthkariWidgetSnapshot.self, from: data)
            guard snapshot.version > 0 else {
                return fallbackSnapshot()
            }
            return snapshot
        } catch {
            return fallbackSnapshot()
        }
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

enum AthkariWidgetRoutes {
    static let home = "athkari://home"

    static func session(slotKey: String) -> String {
        "athkari://session?slot=\(slotKey)"
    }

    static func prayer(slotKey: String?) -> String {
        guard let slotKey, !slotKey.isEmpty else {
            return home
        }
        return session(slotKey: slotKey)
    }
}
