import ActivityKit
import Foundation

@MainActor
final class LiveActivityCoordinator {
    struct SessionSnapshot: Equatable {
        let slotKey: String
        let title: String
        let subtitle: String
        let currentCount: Int
        let targetCount: Int
        let progress: Double
    }

    struct PrayerWindowSnapshot: Equatable {
        let slotKey: String
        let title: String
        let subtitle: String
        let prayerName: String
        let windowStartDate: Date
        let windowEndDate: Date
    }

    static let defaultDismissMinutes = 30

    private var sessionSnapshot: SessionSnapshot?
    private var prayerWindowSnapshot: PrayerWindowSnapshot?
    private var activeActivity: Activity<AthkariLiveActivityAttributes>?
    private var lastRenderedState: AthkariLiveActivityAttributes.ContentState?
    private var dismissPresetMinutes: Int = LiveActivityCoordinator.defaultDismissMinutes

    init() {
        activeActivity = Activity<AthkariLiveActivityAttributes>.activities.first
    }

    func syncSessionState(_ snapshot: SessionSnapshot?) {
        sessionSnapshot = snapshot
        reconcileActivity()
    }

    func syncPrayerWindowState(_ snapshot: PrayerWindowSnapshot?) {
        prayerWindowSnapshot = snapshot
        reconcileActivity()
    }

    func updateDismissPreset(minutes: Int?) {
        dismissPresetMinutes = Self.sanitizeDismissPreset(minutes)
    }

    func endNow() {
        sessionSnapshot = nil
        prayerWindowSnapshot = nil

        guard let activity = activeActivity ?? Activity<AthkariLiveActivityAttributes>.activities.first else {
            activeActivity = nil
            lastRenderedState = nil
            return
        }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        activeActivity = nil
        lastRenderedState = nil
    }

    static func sanitizeDismissPreset(_ minutes: Int?) -> Int {
        guard let minutes, [15, 30, 60].contains(minutes) else {
            return defaultDismissMinutes
        }
        return minutes
    }

    static func resolveContentState(
        sessionSnapshot: SessionSnapshot?,
        prayerWindowSnapshot: PrayerWindowSnapshot?
    ) -> AthkariLiveActivityAttributes.ContentState? {
        let now = Date()

        if let sessionSnapshot {
            return AthkariLiveActivityAttributes.ContentState(
                mode: .session,
                title: sessionSnapshot.title,
                subtitle: sessionSnapshot.subtitle,
                currentCount: sessionSnapshot.currentCount,
                targetCount: sessionSnapshot.targetCount,
                progress: sessionSnapshot.progress,
                slotKey: sessionSnapshot.slotKey,
                prayerName: nil,
                windowEndDate: nil,
                lastUpdated: now
            )
        }

        if let prayerWindowSnapshot {
            return AthkariLiveActivityAttributes.ContentState(
                mode: .prayerWindow,
                title: prayerWindowSnapshot.title,
                subtitle: prayerWindowSnapshot.subtitle,
                currentCount: 0,
                targetCount: 0,
                progress: 0,
                slotKey: prayerWindowSnapshot.slotKey,
                prayerName: prayerWindowSnapshot.prayerName,
                windowEndDate: prayerWindowSnapshot.windowEndDate,
                lastUpdated: now
            )
        }

        return nil
    }

    private func reconcileActivity() {
        let desiredState = Self.resolveContentState(
            sessionSnapshot: sessionSnapshot,
            prayerWindowSnapshot: prayerWindowSnapshot
        )

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endNow()
            return
        }

        guard let desiredState else {
            scheduleActivityEnd()
            return
        }

        if let existingActivity = activeActivity ?? Activity<AthkariLiveActivityAttributes>.activities.first {
            activeActivity = existingActivity

            if let lastRenderedState,
               state(lastRenderedState, isEquivalentTo: desiredState) {
                return
            }

            let staleDate = desiredState.windowEndDate
            let content = ActivityContent(state: desiredState, staleDate: staleDate)
            Task {
                await existingActivity.update(content)
            }
            lastRenderedState = desiredState
            return
        }

        let attributes = AthkariLiveActivityAttributes(activityID: UUID().uuidString)
        let staleDate = desiredState.windowEndDate
        let content = ActivityContent(state: desiredState, staleDate: staleDate)

        do {
            let activity = try Activity.request(attributes: attributes, content: content)
            activeActivity = activity
            lastRenderedState = desiredState
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private func scheduleActivityEnd() {
        guard let existingActivity = activeActivity ?? Activity<AthkariLiveActivityAttributes>.activities.first else {
            activeActivity = nil
            lastRenderedState = nil
            return
        }

        let dismissalDate = Date().addingTimeInterval(Double(dismissPresetMinutes) * 60)

        Task {
            await existingActivity.end(
                nil,
                dismissalPolicy: .after(dismissalDate)
            )
        }

        activeActivity = nil
        lastRenderedState = nil
    }

    private func state(
        _ lhs: AthkariLiveActivityAttributes.ContentState,
        isEquivalentTo rhs: AthkariLiveActivityAttributes.ContentState
    ) -> Bool {
        lhs.mode == rhs.mode &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.currentCount == rhs.currentCount &&
        lhs.targetCount == rhs.targetCount &&
        abs(lhs.progress - rhs.progress) < 0.0001 &&
        lhs.slotKey == rhs.slotKey &&
        lhs.prayerName == rhs.prayerName &&
        lhs.windowEndDate == rhs.windowEndDate
    }
}
