import SwiftUI
import WidgetKit

private enum HeroWidgetPalette {
    static let card = Color(hex: "E6DCCA")
    static let textPrimary = Color(hex: "2C261F")
    static let textSecondary = Color(hex: "2C261F").opacity(0.65)
    static let progressTrack = Color.black.opacity(0.10)
    static let progressFill = Color(hex: "2C261F")
    static let iconCircle = Color.white.opacity(0.30)
}

private struct AthkariHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: AthkariWidgetSnapshot
}

private struct AthkariHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AthkariHomeEntry {
        AthkariHomeEntry(date: Date(), snapshot: AthkariWidgetSnapshot.fallbackSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (AthkariHomeEntry) -> Void) {
        let now = Date()
        completion(AthkariHomeEntry(date: now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AthkariHomeEntry>) -> Void) {
        let now = Date()
        let snapshot = loadSnapshot()
        let entry = AthkariHomeEntry(date: now, snapshot: snapshot)
        let nextRefresh = nextRefreshDate(for: snapshot, now: now) ?? now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> AthkariWidgetSnapshot {
        let defaults = UserDefaults(suiteName: AthkariWidgetSnapshot.appGroupIdentifier)
        let data = defaults?.data(forKey: AthkariWidgetSnapshot.storageKey)
        return AthkariWidgetSnapshot.decode(from: data)
    }

    private func nextRefreshDate(for snapshot: AthkariWidgetSnapshot, now: Date) -> Date? {
        let candidates = [
            snapshot.session?.windowEndDate,
            snapshot.prayer?.nextPrayerDate,
            snapshot.prayer?.windowEndDate
        ]
            .compactMap { $0 }
            .filter { $0 > now }
        return candidates.min()
    }
}

struct AthkariHomeWidget: Widget {
    private let kind = AthkariWidgetSnapshot.homeWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AthkariHomeProvider()) { entry in
            AthkariHomeWidgetView(entry: entry)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .widgetURL(URL(string: entry.snapshot.effectiveRouteURL))
                .containerBackground(for: .widget) {
                    HeroWidgetPalette.card
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("أذكاري")
        .description("بطاقة الرئيسية: نفس معلومات الهيرو مع مزامنة دقيقة.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HeroWidgetContent {
    let header: String
    let title: String
    let primaryLine: String
    let secondaryLine: String?
    let completionText: String
    let iconSystemName: String
    let progress: Double
}

private struct AthkariHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: AthkariHomeEntry

    private var isSmall: Bool {
        family == .systemSmall
    }

    private var content: HeroWidgetContent {
        makeContent(from: entry.snapshot)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSmall ? 24 : 32, style: .continuous)
                .fill(HeroWidgetPalette.card)

            VStack(spacing: isSmall ? 10 : 16) {
                headerRow
                progressBar
                footerRow
            }
            .padding(.horizontal, isSmall ? 14 : 20)
            .padding(.vertical, isSmall ? 14 : 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: isSmall ? 10 : 16) {
            VStack(alignment: .trailing, spacing: isSmall ? 2 : 4) {
                Text(content.header)
                    .font(.system(size: isSmall ? 12 : 14, weight: .semibold))
                    .foregroundStyle(HeroWidgetPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(content.title)
                    .font(.system(size: isSmall ? 20 : 24, weight: .heavy))
                    .lineLimit(isSmall ? 2 : 1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(HeroWidgetPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Spacer(minLength: 0)

            Circle()
                .fill(HeroWidgetPalette.iconCircle)
                .frame(width: isSmall ? 42 : 48, height: isSmall ? 42 : 48)
                .overlay(
                    Image(systemName: content.iconSystemName)
                        .font(.system(size: isSmall ? 16 : 18, weight: .bold))
                        .foregroundStyle(HeroWidgetPalette.textPrimary)
                )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HeroWidgetPalette.progressTrack)

                Capsule()
                    .fill(HeroWidgetPalette.progressFill)
                    .frame(width: proxy.size.width * CGFloat(min(max(content.progress, 0), 1)))
            }
        }
        .frame(height: isSmall ? 5 : 6)
    }

    private var footerRow: some View {
        HStack(alignment: .bottom, spacing: isSmall ? 8 : 16) {
            VStack(alignment: .trailing, spacing: isSmall ? 2 : 5) {
                Text(content.primaryLine)
                    .font(.system(size: isSmall ? 10 : 11, weight: .bold))
                    .foregroundStyle(HeroWidgetPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .layoutPriority(3)

                if let secondary = content.secondaryLine {
                    Text(secondary)
                        .font(.system(size: isSmall ? 9 : 10, weight: .medium))
                        .foregroundStyle(HeroWidgetPalette.textSecondary.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .layoutPriority(3)

            Text(content.completionText)
                .font(.system(size: isSmall ? 11 : 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(HeroWidgetPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(width: isSmall ? 78 : 92, alignment: .trailing)
        }
    }

    private func makeContent(from snapshot: AthkariWidgetSnapshot) -> HeroWidgetContent {
        switch snapshot.activeContent {
        case .session(let session):
            let primary = session.heroPrimaryLine ?? session.subtitle
            let secondary = session.heroSecondaryLine
                ?? session.nextTitle.map { "التالي: \($0)" }
            let completion = session.completionText
                ?? defaultCompletionText(currentCount: session.currentCount, targetCount: session.targetCount)
            let icon = sanitizedIcon(session.iconSystemName, fallback: slotIcon(for: session.slotKey))

            return HeroWidgetContent(
                header: session.heroLabel ?? "الذكر الحالي",
                title: session.title,
                primaryLine: primary,
                secondaryLine: secondary,
                completionText: completion,
                iconSystemName: icon,
                progress: session.normalizedProgress
            )

        case .prayer(let prayer):
            let primary: String
            if let next = prayer.nextPrayerDate, next > entry.date {
                primary = "تبدأ بعد \(durationText(until: next))"
            } else {
                primary = "الصلاة القادمة"
            }

            return HeroWidgetContent(
                header: "الذكر القادم",
                title: prayer.label,
                primaryLine: primary,
                secondaryLine: "التالي: \(prayer.nextPrayerName)",
                completionText: fallbackPrayerCompletionText(from: prayer),
                iconSystemName: "clock.fill",
                progress: 0
            )

        case .fallback(let fallback):
            return HeroWidgetContent(
                header: "الذكر القادم",
                title: "لا يوجد ذكر حالي",
                primaryLine: fallback.subtitle,
                secondaryLine: "افتح التطبيق للمتابعة",
                completionText: "0/0 مكتمل",
                iconSystemName: "sparkles",
                progress: 0
            )
        }
    }

    private func defaultCompletionText(currentCount: Int, targetCount: Int) -> String {
        if targetCount <= 0 {
            return "مكتمل"
        }
        return "\(currentCount)/\(targetCount) مكتمل"
    }

    private func fallbackPrayerCompletionText(from prayer: AthkariWidgetSnapshot.PrayerContent) -> String {
        guard let date = prayer.nextPrayerDate else {
            return "جاهز"
        }
        return clockText(for: date)
    }

    private func clockText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm"
        let suffix = Calendar.current.component(.hour, from: date) >= 12 ? "م" : "ص"
        return "\(formatter.string(from: date)) \(suffix)"
    }

    private func durationText(until date: Date) -> String {
        let seconds = max(Int(date.timeIntervalSince(entry.date)), 0)
        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)س \(remainingMinutes)د"
        }
        return "\(remainingMinutes)د"
    }

    private func sanitizedIcon(_ candidate: String?, fallback: String) -> String {
        guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else {
            return fallback
        }
        return candidate
    }

    private func slotIcon(for slot: String) -> String {
        switch slot {
        case "waking_up", "morning", "after_fajr":
            return "sunrise.fill"
        case "after_dhuhr":
            return "sun.max.fill"
        case "after_asr":
            return "sun.haze.fill"
        case "after_maghrib", "evening":
            return "sunset.fill"
        case "after_isha", "sleep":
            return "moon.zzz.fill"
        default:
            return "hands.sparkles.fill"
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64

        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
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
