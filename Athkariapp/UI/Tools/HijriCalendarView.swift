import SwiftUI

// MARK: - Calendar Models

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    var isSpecialDay: Bool = false
    var eventType: IslamicEventType?
}

enum IslamicEventType {
    case friday
    case whiteDay
    case ramadan
    case specialOccasion
}

struct HijriCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentDate = Date()
    @State private var selectedDate: Date = Date()
    @State private var officialHijriDate: HijriDateInfo?
    @State private var isLoading = false
    @State private var dragOffset: CGFloat = 0
    
    // Calendar setup
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar_SA@numbers=latn")
        return cal
    }()
    
    private let gregorian: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ar_SA@numbers=latn")
        return cal
    }()
    
    // Days of week
    private let daysOfWeek = ["ح", "ن", "ث", "ر", "خ", "ج", "س"]
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            // Ambient Background
            AmbientBackground()
                .opacity(0.3)
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    
                    Spacer()
                    
                    Text("التقويم الهجري")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Empty space for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero Card - Official Date
                        HijriHeroCard(
                            hijriDate: officialHijriDate,
                            isLoading: isLoading,
                            currentDate: currentDate,
                            gregorian: gregorian
                        )
                        
                        // Calendar Card
                        VStack(spacing: 24) {
                            // Month Navigation Header
                            HStack {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        changeMonth(by: -1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.05))
                                        )
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text(monthYearString(for: currentDate))
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    
                                    Text(gregorianDateString(for: currentDate))
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textGray)
                                }
                                
                                Spacer()
                                
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        changeMonth(by: 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.05))
                                        )
                                }
                            }
                            .padding(.bottom, 8)
                            
                            // Calendar Grid
                            VStack(spacing: 16) {
                                // Weekday Headers
                                HStack(spacing: 0) {
                                    ForEach(daysOfWeek, id: \.self) { day in
                                        Text(day)
                                            .font(.caption.bold())
                                            .foregroundStyle(AppColors.textGray)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                
                                // Days Grid
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                                    ForEach(daysInMonth()) { dayItem in
                                        if let date = dayItem.date {
                                            EnhancedDayCell(
                                                date: date,
                                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                                isToday: calendar.isDateInToday(date),
                                                isSpecialDay: dayItem.isSpecialDay,
                                                eventType: dayItem.eventType,
                                                calendar: calendar
                                            ) {
                                                withAnimation(.spring(response: 0.3)) {
                                                    selectedDate = date
                                                }
                                            }
                                        } else {
                                            Color.clear.frame(height: 44)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(AppColors.sessionSurface)
                                
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            }
                        )
                        
                        // Events Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.onboardingPrimary)
                                
                                Text("المناسبات القادمة")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                ForEach(upcomingEvents(), id: \.title) { event in
                                    IslamicEventCard(event: event)
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .task {
            await fetchOfficialDate()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    if abs(value.translation.width) > 100 {
                        withAnimation(.spring(response: 0.3)) {
                            changeMonth(by: value.translation.width > 0 ? -1 : 1)
                        }
                    }
                    dragOffset = 0
                }
        )
    }
    
    // MARK: - Logic
    
    private func fetchOfficialDate() async {
        isLoading = true
        do {
            let info = try await HijriDateService.shared.fetchHijriDate()
            await MainActor.run {
                officialHijriDate = info
                isLoading = false
            }
        } catch {
            print("Failed to fetch Hijri date: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func jumpToToday() {
        withAnimation(.spring(response: 0.3)) {
            currentDate = Date()
            selectedDate = Date()
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ar_SA@numbers=latn")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func gregorianDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = gregorian
        formatter.locale = Locale(identifier: "ar_SA@numbers=latn")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func daysInMonth() -> [CalendarDay] {
        guard let range = calendar.range(of: .day, in: .month, for: currentDate),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        var days: [CalendarDay] = []
        
        // Add padding days for the start of the week
        for _ in 0..<(firstWeekday - 1) {
            days.append(CalendarDay(date: nil))
        }
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                let dayNum = calendar.component(.day, from: date)
                let weekday = calendar.component(.weekday, from: date)
                
                var calDay = CalendarDay(date: date)
                
                // Mark special days
                if weekday == 6 { // Friday
                    calDay.isSpecialDay = true
                    calDay.eventType = .friday
                } else if [13, 14, 15].contains(dayNum) { // White days
                    calDay.isSpecialDay = true
                    calDay.eventType = .whiteDay
                }
                
                days.append(calDay)
            }
        }
        
        return days
    }
    
    private func upcomingEvents() -> [IslamicEvent] {
        var events: [IslamicEvent] = []
        let now = calendar.startOfDay(for: Date())
        
        // --- Helper for Arabic Days ---
        func formatArabicDays(_ days: Int) -> String {
            if days == 0 { return "اليوم" }
            if days == 1 { return "غداً" }
            if days == 2 { return "بعد يومين" }
            if days >= 3 && days <= 10 { return "بعد \(days) أيام" }
            return "بعد \(days) يوم"
        }
        
        // --- Helper for Hijri Proximity ---
        func daysUntilHijri(month: Int, day: Int) -> Int? {
            let currentYear = calendar.component(.year, from: now)
            var components = DateComponents(year: currentYear, month: month, day: day)
            
            if let date = calendar.date(from: components) {
                let targetDate = calendar.startOfDay(for: date)
                if targetDate >= now {
                    return calendar.dateComponents([.day], from: now, to: targetDate).day
                }
            }
            
            // Try next year
            components.year = currentYear + 1
            if let date = calendar.date(from: components) {
                return calendar.dateComponents([.day], from: now, to: calendar.startOfDay(for: date)).day
            }
            return nil
        }
        
        // 🌙 White Days (13-15)
        let hijriDay = calendar.component(.day, from: now)
        if hijriDay < 13 {
            let diff = 13 - hijriDay
            events.append(IslamicEvent(title: "الأيام البيض", subtitle: "صيام ١٣-١٤-١٥", date: formatArabicDays(diff), icon: "moon.fill", color: .white, sortOrder: diff))
        } else if hijriDay <= 15 {
            events.append(IslamicEvent(title: "الأيام البيض", subtitle: "صيام الأيام البيض", date: "الآن", icon: "moon.fill", color: AppColors.onboardingPrimary, sortOrder: 0))
        }
        
        // 🕋 Day of Arafah (9 Dhu al-Hijjah)
        if let diff = daysUntilHijri(month: 12, day: 9) {
            events.append(IslamicEvent(title: "يوم عرفة", subtitle: "خير يوم طلعت فيه الشمس", date: formatArabicDays(diff), icon: "hands.and.sparkles.fill", color: AppColors.onboardingPrimary, sortOrder: diff))
        }
        
        // 🕋 Eid Al-Adha (10 Dhu al-Hijjah)
        if let diff = daysUntilHijri(month: 12, day: 10) {
            events.append(IslamicEvent(title: "عيد الأضحى المبارك", subtitle: "عيد النحر", date: formatArabicDays(diff), icon: "moon.stars.fill", color: AppColors.onboardingPrimary, sortOrder: diff))
        }
        
        // 🌙 Eid Al-Fitr (1 Shawwal)
        if let diff = daysUntilHijri(month: 10, day: 1) {
            events.append(IslamicEvent(title: "عيد الفطر المبارك", subtitle: "١ شوال", date: formatArabicDays(diff), icon: "sparkles", color: .yellow, sortOrder: diff))
        }
        
        // 🇸🇦 Saudi National Day (Sep 23)
        let gYear = gregorian.component(.year, from: Date())
        if let nationalDay = gregorian.date(from: DateComponents(year: gYear, month: 9, day: 23)) {
            let target = nationalDay < now ? gregorian.date(from: DateComponents(year: gYear + 1, month: 9, day: 23))! : nationalDay
            let diff = gregorian.dateComponents([.day], from: now, to: gregorian.startOfDay(for: target)).day ?? 0
            events.append(IslamicEvent(title: "اليوم الوطني السعودي", subtitle: "ذكرى التوحيد", date: formatArabicDays(diff), icon: "flag.fill", color: Color(hex: "006C35"), sortOrder: diff))
        }
        
        // 🇸🇦 Saudi Founding Day (Feb 22)
        if let foundingDay = gregorian.date(from: DateComponents(year: gYear, month: 2, day: 22)) {
            let target = foundingDay < now ? gregorian.date(from: DateComponents(year: gYear + 1, month: 2, day: 22))! : foundingDay
            let diff = gregorian.dateComponents([.day], from: now, to: gregorian.startOfDay(for: target)).day ?? 0
            events.append(IslamicEvent(title: "يوم التأسيس السعودي", subtitle: "ذكرى التأسيس", date: formatArabicDays(diff), icon: "shield.fill", color: Color(hex: "006C35"), sortOrder: diff))
        }
        
        // 🕌 Next Friday
        let weekday = calendar.component(.weekday, from: now)
        let diff = (13 - weekday) % 7
        if diff >= 0 {
            events.append(IslamicEvent(title: "يوم الجمعة", subtitle: "سورة الكهف والجمعة", date: formatArabicDays(diff), icon: "mosque.fill", color: AppColors.success, sortOrder: diff))
        }
        
        return events.sorted(by: { $0.sortOrder < $1.sortOrder }).prefix(5).map { $0 }
    }
}

// MARK: - Hero Card Component

struct HijriHeroCard: View {
    let hijriDate: HijriDateInfo?
    let isLoading: Bool
    let currentDate: Date
    let gregorian: Calendar
    
    var body: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: 32)
                .fill(AppColors.sessionSurface)
            
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.onboardingPrimary.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Border
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.onboardingPrimary.opacity(0.3),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            VStack {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.onboardingPrimary)
                                .frame(width: 6, height: 6)
                            
                            Text("تاريخ اليوم")
                                .font(.caption.bold())
                                .foregroundStyle(AppColors.onboardingPrimary)
                                .textCase(.uppercase)
                            
                            if isLoading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(AppColors.onboardingPrimary)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        Text(hijriWeekday())
                            .font(.title3.bold())
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text(hijriDateString())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(gregorianString())
                            .font(.caption)
                            .foregroundStyle(AppColors.textGray)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Decorative moon icon
                    ZStack {
                        Circle()
                            .fill(AppColors.onboardingPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .blur(radius: 20)
                        
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.onboardingPrimary, AppColors.onboardingPrimary.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .padding(24)
            }
        }
        .frame(height: 160)
        .shadow(color: AppColors.onboardingPrimary.opacity(0.1), radius: 20, y: 10)
    }
    
    private func hijriWeekday() -> String {
        if let official = hijriDate {
            return official.weekday.ar
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    private func hijriDateString() -> String {
        if let official = hijriDate {
            return "\(official.day) \(official.month.ar) \(official.year)"
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "ar_SA@numbers=latn")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func gregorianString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = gregorian
        formatter.locale = Locale(identifier: "ar_SA@numbers=latn")
        formatter.dateFormat = "EEEE، d MMMM yyyy"
        return formatter.string(from: Date()) // Always today in hero card
    }
}

// MARK: - Enhanced Day Cell

struct EnhancedDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isSpecialDay: Bool
    let eventType: IslamicEventType?
    let calendar: Calendar
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(calendar.component(.day, from: date).formatted(.number.locale(Locale(identifier: "en"))))
                    .font(.system(size: 16, weight: isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(textColor)
                
                // Indicator dot for special days
                if isSpecialDay && !isSelected {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
            .frame(width: 44, height: 44)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isToday ? 2 : 0)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(color: isSelected ? AppColors.onboardingPrimary.opacity(0.3) : .clear, radius: 8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return AppColors.onboardingPrimary
        } else {
            return .white.opacity(0.9)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return AppColors.onboardingPrimary
        } else if isToday {
            return AppColors.onboardingPrimary.opacity(0.15)
        } else if isSpecialDay {
            return Color.white.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isToday && !isSelected {
            return AppColors.onboardingPrimary
        }
        return .clear
    }
    
    private var indicatorColor: Color {
        switch eventType {
        case .friday:
            return AppColors.success
        case .whiteDay:
            return .white
        case .ramadan:
            return AppColors.onboardingPrimary
        default:
            return AppColors.textGray
        }
    }
}

// MARK: - Islamic Event Card

struct IslamicEvent {
    let title: String
    let subtitle: String
    let date: String
    let icon: String
    let color: Color
    let sortOrder: Int
}

struct IslamicEventCard: View {
    let event: IslamicEvent
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: event.icon)
                    .font(.title3)
                    .foregroundStyle(event.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(event.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textGray)
            }
            
            Spacer()
            
            Text(event.date)
                .font(.caption.bold())
                .foregroundStyle(event.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(event.color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.sessionSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}


