import Foundation
import WidgetKit

@MainActor
final class WidgetSnapshotCoordinator {
    struct NextPrayerSnapshot: Equatable, Sendable {
        let name: String
        let date: Date
    }

    struct HeroCardSnapshot: Equatable, Sendable {
        let slotKey: String?
        let headerLabel: String
        let title: String
        let subtitle: String
        let heroPrimaryLine: String
        let heroSecondaryLine: String?
        let completionText: String?
        let currentCount: Int
        let targetCount: Int
        let progress: Double
        let windowEndDate: Date?
        let nextTitle: String?
        let iconSystemName: String?
        let routeURL: String
    }

    private let defaults: UserDefaults
    private let nowProvider: () -> Date
    private let minReloadInterval: TimeInterval

    private var sessionSnapshot: LiveActivityCoordinator.SessionSnapshot?
    private var heroCardSnapshot: HeroCardSnapshot?
    private var prayerWindowSnapshot: LiveActivityCoordinator.PrayerWindowSnapshot?
    private var nextPrayerSnapshot: NextPrayerSnapshot?
    private var lastReloadAt: Date?

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: AthkariWidgetSnapshot.appGroupIdentifier),
        nowProvider: @escaping () -> Date = Date.init,
        minReloadInterval: TimeInterval = 10
    ) {
        self.defaults = defaults ?? .standard
        self.nowProvider = nowProvider
        self.minReloadInterval = minReloadInterval
    }

    func syncSession(_ snapshot: LiveActivityCoordinator.SessionSnapshot?) {
        sessionSnapshot = snapshot
        persistSnapshot()
    }

    func syncHeroCard(_ snapshot: HeroCardSnapshot?) {
        heroCardSnapshot = snapshot
        persistSnapshot()
    }

    func syncPrayerWindow(_ snapshot: LiveActivityCoordinator.PrayerWindowSnapshot?) {
        prayerWindowSnapshot = snapshot
        persistSnapshot()
    }

    func syncNextPrayer(name: String?, date: Date?) {
        if
            let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty,
            let date
        {
            nextPrayerSnapshot = NextPrayerSnapshot(name: name, date: date)
        } else {
            nextPrayerSnapshot = nil
        }

        persistSnapshot()
    }

    func clearAll() {
        sessionSnapshot = nil
        heroCardSnapshot = nil
        prayerWindowSnapshot = nil
        nextPrayerSnapshot = nil
        persistSnapshot()
    }

    private func persistSnapshot() {
        let snapshot = Self.makeSnapshot(
            currentDate: nowProvider(),
            session: sessionSnapshot,
            heroCard: heroCardSnapshot,
            prayerWindow: prayerWindowSnapshot,
            nextPrayer: nextPrayerSnapshot
        )

        if let encoded = snapshot.encode() {
            defaults.set(encoded, forKey: AthkariWidgetSnapshot.storageKey)
        } else {
            defaults.removeObject(forKey: AthkariWidgetSnapshot.storageKey)
        }

        reloadWidgetIfNeeded(at: snapshot.generatedAt)
    }

    private func reloadWidgetIfNeeded(at date: Date) {
        if let lastReloadAt, date.timeIntervalSince(lastReloadAt) < minReloadInterval {
            return
        }

        lastReloadAt = date
        WidgetCenter.shared.reloadTimelines(ofKind: AthkariWidgetSnapshot.homeWidgetKind)
    }

    static func makeSnapshot(
        currentDate: Date,
        session: LiveActivityCoordinator.SessionSnapshot?,
        heroCard: HeroCardSnapshot? = nil,
        prayerWindow: LiveActivityCoordinator.PrayerWindowSnapshot?,
        nextPrayer: NextPrayerSnapshot?
    ) -> AthkariWidgetSnapshot {
        let sessionContent: AthkariWidgetSnapshot.SessionContent?
        if let session {
            let safeTarget = max(session.targetCount, 1)
            let safeCurrent = min(max(session.currentCount, 0), safeTarget)
            sessionContent = AthkariWidgetSnapshot.SessionContent(
                slotKey: session.slotKey,
                title: session.title,
                subtitle: session.subtitle,
                currentCount: safeCurrent,
                targetCount: safeTarget,
                progress: min(max(session.progress, 0), 1),
                heroLabel: nil,
                heroPrimaryLine: nil,
                heroSecondaryLine: nil,
                completionText: nil,
                nextTitle: nil,
                windowEndDate: nil,
                iconSystemName: nil,
                routeURL: AthkariWidgetRoutes.session(slotKey: session.slotKey)
            )
        } else if let heroCard {
            let safeTarget = max(heroCard.targetCount, 0)
            let safeCurrent = min(max(heroCard.currentCount, 0), safeTarget)
            let routeURL = heroCard.routeURL.isEmpty ? AthkariWidgetRoutes.home : heroCard.routeURL
            sessionContent = AthkariWidgetSnapshot.SessionContent(
                slotKey: heroCard.slotKey ?? "home",
                title: heroCard.title,
                subtitle: heroCard.subtitle,
                currentCount: safeCurrent,
                targetCount: safeTarget,
                progress: min(max(heroCard.progress, 0), 1),
                heroLabel: heroCard.headerLabel,
                heroPrimaryLine: heroCard.heroPrimaryLine,
                heroSecondaryLine: heroCard.heroSecondaryLine,
                completionText: heroCard.completionText,
                nextTitle: heroCard.nextTitle,
                windowEndDate: heroCard.windowEndDate,
                iconSystemName: heroCard.iconSystemName,
                routeURL: routeURL
            )
        } else {
            sessionContent = nil
        }

        let prayerContent: AthkariWidgetSnapshot.PrayerContent?
        if prayerWindow != nil || nextPrayer != nil {
            let label = prayerWindow?.title ?? "الصلاة القادمة"
            let nextPrayerName = nextPrayer?.name ?? prayerWindow?.prayerName ?? "الصلاة القادمة"
            prayerContent = AthkariWidgetSnapshot.PrayerContent(
                label: label,
                nextPrayerName: nextPrayerName,
                nextPrayerDate: nextPrayer?.date,
                windowEndDate: prayerWindow?.windowEndDate,
                slotKey: prayerWindow?.slotKey,
                routeURL: AthkariWidgetRoutes.prayer(slotKey: prayerWindow?.slotKey)
            )
        } else {
            prayerContent = nil
        }

        var snapshot = AthkariWidgetSnapshot.fallbackSnapshot(generatedAt: currentDate)
        snapshot.session = sessionContent
        snapshot.prayer = prayerContent
        return snapshot
    }
}
