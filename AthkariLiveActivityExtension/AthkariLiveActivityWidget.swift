import ActivityKit
import SwiftUI
import WidgetKit

struct AthkariLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AthkariLiveActivityAttributes.self) { context in
            LockScreenActivityCard(state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(destinationURL(for: context.state))
                .environment(\.layoutDirection, .rightToLeft)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ModeChip(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.mode == .session {
                        SessionValueBadge(state: context.state)
                    } else {
                        PrayerTimerBadge(state: context.state, compact: true)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    HeaderBlock(state: context.state, multilineBody: false)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.mode == .session {
                        SessionBottomBlock(state: context.state)
                    } else {
                        PrayerBottomBlock(state: context.state)
                    }
                }
            } compactLeading: {
                if context.state.mode == .session {
                    Text(sessionValueText(for: context.state))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.white)
                } else {
                    PrayerCompactTimer(state: context.state)
                }
            } compactTrailing: {
                ModeDot(state: context.state)
            } minimal: {
                ModeDot(state: context.state)
            }
            .keylineTint(theme(for: context.state).accent)
            .widgetURL(destinationURL(for: context.state))
        }
    }

    private func destinationURL(for state: AthkariLiveActivityAttributes.ContentState) -> URL? {
        if state.mode == .session, let slotKey = state.slotKey {
            return URL(string: "athkari://session?slot=\(slotKey)")
        }
        if state.mode == .prayerWindow, let slotKey = state.slotKey {
            return URL(string: "athkari://session?slot=\(slotKey)")
        }
        return URL(string: "athkari://home")
    }
}

private struct LockScreenActivityCard: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        let currentTheme = theme(for: state)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                HeaderBlock(state: state, multilineBody: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if state.mode == .session {
                    SessionValueBadge(state: state)
                } else {
                    ModeDot(state: state)
                        .frame(width: 34, height: 34)
                }
            }

            if state.mode == .session {
                SessionBottomBlock(state: state)
            } else {
                PrayerBottomBlock(state: state)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(currentTheme.gradient.opacity(0.26))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

private struct HeaderBlock: View {
    let state: AthkariLiveActivityAttributes.ContentState
    let multilineBody: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                ModeChip(state: state)
                Spacer(minLength: 0)
            }

            Text(state.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(multilineBody ? 2 : 1)
                .fixedSize(horizontal: false, vertical: multilineBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            Text(state.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(multilineBody ? 4 : 1)
                .fixedSize(horizontal: false, vertical: multilineBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
}

private struct SessionBottomBlock: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        let currentTheme = theme(for: state)
        let hasTarget = state.targetCount > 0
        let target = max(state.targetCount, 1)
        let remaining = max(target - state.currentCount, 0)

        VStack(spacing: 7) {
            if hasTarget {
                ProgressView(value: state.normalizedProgress)
                    .tint(currentTheme.accent)
            } else {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(height: 4)
            }

            HStack(spacing: 8) {
                MetricTag(icon: "number", text: sessionValueText(for: state))
                if hasTarget {
                    MetricTag(icon: "target", text: "متبقي \(remaining)")
                } else {
                    MetricTag(icon: "target", text: "بدون هدف")
                }
                if let nextURL = nextDhikrURL(for: state) {
                    Link(destination: nextURL) {
                        HStack(spacing: 4) {
                            Text("تابع القراءة")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "backward.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(theme(for: state).accent.opacity(0.26), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(theme(for: state).accent.opacity(0.55), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PrayerBottomBlock: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("حتى نهاية النافذة")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.74))
                .frame(maxWidth: .infinity, alignment: .leading)

            PrayerTimerBadge(state: state, compact: false)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SessionValueBadge: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        let currentTheme = theme(for: state)
        let hasTarget = state.targetCount > 0

        VStack(alignment: .leading, spacing: 2) {
            Text(sessionValueText(for: state))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if hasTarget {
                Text("\(Int(state.normalizedProgress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(currentTheme.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.1), in: Capsule())
    }
}

private struct PrayerTimerBadge: View {
    let state: AthkariLiveActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        if let endDate = state.windowEndDate, endDate > Date() {
            HStack(spacing: compact ? 4 : 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Text(timerInterval: Date()...endDate, countsDown: true)
                    .font(.system(size: compact ? 11 : 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(.white.opacity(0.1), in: Capsule())
        } else {
            Text("انتهت النافذة")
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}

private struct PrayerCompactTimer: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        if let endDate = state.windowEndDate, endDate > Date() {
            Text(timerInterval: Date()...endDate, countsDown: true)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(.white)
        } else {
            Text("انتهت")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }
}

private struct MetricTag: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08), in: Capsule())
    }
}

private struct ModeChip: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        let currentTheme = theme(for: state)
        HStack(spacing: 5) {
            Image(systemName: currentTheme.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(currentTheme.accent)
            Text(modeLabel(for: state))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(currentTheme.gradient.opacity(0.3), in: Capsule())
        .overlay(
            Capsule()
                .stroke(currentTheme.accent.opacity(0.48), lineWidth: 1)
        )
    }
}

private struct ModeDot: View {
    let state: AthkariLiveActivityAttributes.ContentState

    var body: some View {
        let currentTheme = theme(for: state)
        ZStack {
            Circle()
                .fill(currentTheme.gradient.opacity(0.35))
            Image(systemName: currentTheme.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 20, height: 20)
    }
}

private struct ActivityTheme {
    let accent: Color
    let start: Color
    let end: Color
    let icon: String

    var gradient: LinearGradient {
        LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private func theme(for state: AthkariLiveActivityAttributes.ContentState) -> ActivityTheme {
    switch state.mode {
    case .session:
        return ActivityTheme(
            accent: Color(red: 0.20, green: 0.87, blue: 0.64),
            start: Color(red: 0.09, green: 0.43, blue: 0.34),
            end: Color(red: 0.08, green: 0.23, blue: 0.32),
            icon: slotIcon(for: state.slotKey) ?? "dot.radiowaves.left.and.right"
        )
    case .prayerWindow:
        return ActivityTheme(
            accent: Color(red: 0.98, green: 0.74, blue: 0.28),
            start: Color(red: 0.38, green: 0.24, blue: 0.10),
            end: Color(red: 0.14, green: 0.23, blue: 0.38),
            icon: "clock.badge.checkmark"
        )
    }
}

private func sessionValueText(for state: AthkariLiveActivityAttributes.ContentState) -> String {
    if state.targetCount > 0 {
        return "\(state.currentCount)/\(state.targetCount)"
    }
    return "\(state.currentCount)"
}

private func nextDhikrURL(for state: AthkariLiveActivityAttributes.ContentState) -> URL? {
    guard state.mode == .session, let slotKey = state.slotKey else {
        return nil
    }
    return URL(string: "athkari://session?slot=\(slotKey)&action=next")
}

private func modeLabel(for state: AthkariLiveActivityAttributes.ContentState) -> String {
    switch state.mode {
    case .session:
        return slotShortName(for: state.slotKey) ?? "الذكر"
    case .prayerWindow:
        if let prayer = state.prayerName, !prayer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return prayer
        }
        return "بعد الصلاة"
    }
}

private func slotShortName(for slotRawValue: String?) -> String? {
    guard let slotRawValue else { return nil }

    switch slotRawValue {
    case "waking_up": return "الاستيقاظ"
    case "morning": return "الصباح"
    case "after_fajr": return "بعد الفجر"
    case "after_dhuhr": return "بعد الظهر"
    case "after_asr": return "بعد العصر"
    case "after_maghrib": return "بعد المغرب"
    case "after_isha": return "بعد العشاء"
    case "evening": return "المساء"
    case "sleep": return "النوم"
    default: return nil
    }
}

private func slotIcon(for slotRawValue: String?) -> String? {
    guard let slotRawValue else { return nil }

    switch slotRawValue {
    case "waking_up", "morning", "after_fajr":
        return "sunrise.fill"
    case "after_dhuhr":
        return "sun.max.fill"
    case "after_asr":
        return "sun.haze.fill"
    case "after_maghrib", "evening":
        return "sunset.fill"
    case "after_isha", "sleep":
        return "moon.fill"
    default:
        return nil
    }
}
