import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class SessionViewModel {
    // MARK: - Published State
    var session: SessionState?
    var currentDhikr: DhikrItem?
    var dhikrList: [DhikrItem] = []
    var currentCount: Int = 0
    var targetCount: Int = 1
    var isCompleted: Bool = false
    var showCompletionCelebration: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var autoAdvance: Bool = false
    var hapticIntensityStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium

    // MARK: - Navigation State
    var showDhikrSwitcher: Bool = false
    var showResetConfirmation: Bool = false
    var showFinishConfirmation: Bool = false

    // MARK: - Dependencies
    // MARK: - Dependencies
    private let sessionRepository: SessionRepository
    private let dhikrRepository: DhikrRepository
    private let settingsRepository: SettingsRepositoryProtocol
    private let hapticsService: HapticsService
    private var hapticsEnabled: Bool = true

    // MARK: - Properties
    let slotKey: SlotKey


    var progress: Double {
        guard targetCount > 0 else { return 0 }
        return min(Double(currentCount) / Double(targetCount), 1.0)
    }

    var remainingCount: Int {
        max(0, targetCount - currentCount)
    }

    var currentDhikrIndex: Int {
        guard let current = currentDhikr else { return 0 }
        return dhikrList.firstIndex(where: { $0.id == current.id }) ?? 0
    }

    // MARK: - Initialization
    init(
        slotKey: SlotKey,
        sessionRepository: SessionRepository,
        dhikrRepository: DhikrRepository,
        settingsRepository: SettingsRepositoryProtocol,
        hapticsService: HapticsService,
        hapticsEnabled: Bool = true
    ) {
        self.slotKey = slotKey
        self.sessionRepository = sessionRepository
        self.dhikrRepository = dhikrRepository
        self.settingsRepository = settingsRepository
        self.hapticsService = hapticsService
        self.hapticsEnabled = hapticsEnabled
    }

    // MARK: - Public Methods
    func loadSession() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get or create session
            session = try sessionRepository.fetchOrCreateSession(date: Date(), slotKey: slotKey)

            // Load dhikr items for this slot
            let category = slotKey.dhikrCategory
            dhikrList = try dhikrRepository.fetchByCategory(category)

            // Set current dhikr
            if let session = session, let currentId = session.currentDhikrId {
                currentDhikr = try dhikrRepository.fetchById(currentId)
            }

            // If no current dhikr, set first one
            if currentDhikr == nil, let first = dhikrList.first {
                currentDhikr = first
                session?.currentDhikrId = first.id
            }

            // Update counts
            currentCount = session?.currentCount ?? 0
            targetCount = currentDhikr?.repeatCount ?? 1
            isCompleted = session?.sessionStatus == .completed

        } catch {
            errorMessage = "حدث خطأ في تحميل الجلسة"
            print("Error loading session: \(error)")
        }

        if let settings = try? settingsRepository.getSettings() {
            autoAdvance = settings.autoAdvance
            hapticIntensityStyle = HapticIntensity(rawValue: settings.hapticIntensity)?.feedbackStyle ?? .medium
            hapticsService.setIntensity(hapticIntensityStyle)
        }

        isLoading = false
    }

    func increment() {
        guard !isCompleted else { return }

        currentCount += 1

        // Play haptic
        if hapticsEnabled {
            hapticsService.playImpact() // Uses default intensity
        }

        // Update session
        session?.currentCount = currentCount
        session?.totalDhikrsCount += 1

        // Check completion
        if currentCount >= targetCount {
            completeCurrentDhikr()
        }

        saveSession()
    }

    func reset() {
        currentCount = 0
        session?.currentCount = 0
        session?.sessionStatus = .partial
        isCompleted = false
        saveSession()
    }

    func switchDhikr(to dhikr: DhikrItem) {
        currentDhikr = dhikr
        currentCount = 0
        targetCount = dhikr.repeatCount
        session?.currentDhikrId = dhikr.id
        session?.currentCount = 0
        saveSession()
        showDhikrSwitcher = false
    }

    func finishSession() {
        guard let session = session else { return }

        // Mark as completed if reached target, otherwise confirm
        if currentCount >= targetCount || !dhikrList.isEmpty {
            session.sessionStatus = .completed
            session.completedAt = Date()
            isCompleted = true
            showCompletionCelebration = true

            if hapticsEnabled {
                hapticsService.playNotification(.success)
            }
        }

        saveSession()
    }

    func endSession() {
        guard let session = session else { return }
        // Only mark as partial if started but not completed
        if session.sessionStatus != .completed && (currentCount > 0 || !session.completedDhikrIds.isEmpty) {
            session.sessionStatus = .partial
        }
        saveSession()
    }

    func moveToNext() {
        guard let current = currentDhikr, let index = dhikrList.firstIndex(where: { $0.id == current.id }) else { return }
        let nextIndex = index + 1
        if nextIndex < dhikrList.count {
            switchDhikr(to: dhikrList[nextIndex])
        }
    }

    func moveToPrevious() {
        guard let current = currentDhikr, let index = dhikrList.firstIndex(where: { $0.id == current.id }) else { return }
        let prevIndex = index - 1
        if prevIndex >= 0 {
            switchDhikr(to: dhikrList[prevIndex])
        }
    }



    func shareText() -> String {
        guard let dhikr = currentDhikr else { return "" }
        var text = dhikr.text
        if let reference = dhikr.reference {
            text += "\n\n\(reference)"
        }
        text += "\n\nمن تطبيق اذكاري"
        return text
    }

    // MARK: - Private Methods
    private func completeCurrentDhikr() {
        guard let session = session, let current = currentDhikr else { return }

        // Add to completed list
        if !session.completedDhikrIds.contains(current.id) {
            session.completedDhikrIds.append(current.id)
        }

        // Check if all dhikr completed
        let allCompleted = dhikrList.allSatisfy { dhikr in
            session.completedDhikrIds.contains(dhikr.id)
        }

        if allCompleted {
            session.sessionStatus = .completed
            session.completedAt = Date()
            isCompleted = true
            showCompletionCelebration = true

            if hapticsEnabled {
                hapticsService.playNotification(.success)
            }
        } else if autoAdvance {
            // Move to next dhikr automatically if preference is enabled
            moveToNextDhikr()
        }
    }

    private func moveToNextDhikr() {
        guard let session = session else { return }

        // Find next incomplete dhikr
        for dhikr in dhikrList {
            if !session.completedDhikrIds.contains(dhikr.id) {
                switchDhikr(to: dhikr)
                return
            }
        }
    }

    private func saveSession() {
        guard let session = session else { return }

        // Update status if started
        if session.sessionStatus == .notStarted && currentCount > 0 {
            session.sessionStatus = .partial
        }

        do {
            try sessionRepository.update(session)
        } catch {
            print("Error saving session: \(error)")
        }
    }
}
