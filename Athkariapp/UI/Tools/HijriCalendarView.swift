import SwiftUI

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
}

struct HijriCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentDate = Date()
    @State private var selectedDate: Date = Date()
    
    // Calendar setup
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar_SA")
        return cal
    }()
    
    private let gregorian: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ar_SA")
        return cal
    }()
    
    // Days of week
    private let daysOfWeek = ["ح", "ن", "ث", "ر", "خ", "ج", "س"]
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Color.clear.frame(width: 40, height: 40)
                    Spacer()
                    Text("التقويم الهجري")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "xmark")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Calendar Card
                        VStack(spacing: 20) {
                            // Month Header
                            HStack {
                                Button {
                                    changeMonth(by: -1)
                                } label: {
                                    Image(systemName: "chevron.right") // RTL context: right is previous/back
                                        .foregroundStyle(.gray)
                                        .padding(10)
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(Circle())
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text(monthYearString(for: currentDate))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    
                                    Text(gregorianDateString(for: currentDate))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                
                                Spacer()
                                
                                Button {
                                    changeMonth(by: 1)
                                } label: {
                                    Image(systemName: "chevron.left") // RTL context: left is next
                                        .foregroundStyle(.gray)
                                        .padding(10)
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Days Grid
                            VStack(spacing: 12) {
                                // Weekday Headers
                                HStack {
                                    ForEach(daysOfWeek, id: \.self) { day in
                                        Text(day)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.gray)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                
                                // Days
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 16) {
                                    ForEach(daysInMonth()) { dayItem in
                                        if let date = dayItem.date {
                                            DayCell(
                                                date: date,
                                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                                isToday: calendar.isDateInToday(date),
                                                calendar: calendar
                                            ) {
                                                selectedDate = date
                                            }
                                        } else {
                                            Color.clear.frame(height: 30)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(AppColors.onboardingSurface)
                        .cornerRadius(32)
                        
                        // Events Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("أحداث الشهر")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                            
                            VStack(spacing: 12) {
                                // Dynamic Events based on date
                                if isRamadan(date: currentDate) {
                                    EventRow(title: "شهر رمضان المبارك", date: "١ رمضان", icon: "star.fill", color: .yellow)
                                }
                                
                                EventRow(title: "الأيام البيض", date: "١٣، ١٤، ١٥", icon: "moon.fill", color: .white)
                                
                                EventRow(title: "يوم الجمعة", date: "كل أسبوع", icon: "moon.stars.fill", color: AppColors.success)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func gregorianDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = gregorian
        formatter.locale = Locale(identifier: "ar_SA")
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
                days.append(CalendarDay(date: date))
            }
        }
        
        return days
    }
    
    private func isRamadan(date: Date) -> Bool {
        let month = calendar.component(.month, from: date)
        return month == 9
    }
}

// MARK: - Subviews for Calendar

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let calendar: Calendar
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : (isToday ? AppColors.success : .white))
            }
            .frame(width: 36, height: 36)
            .background(isSelected ? AppColors.onboardingPrimary : (isToday ? AppColors.onboardingPrimary.opacity(0.2) : Color.clear))
            .clipShape(Circle())
        }
    }
}

struct EventRow: View {
    let title: String
    let date: String
    let icon: String // SF Symbol
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .padding(12)
                .background(AppColors.onboardingSurface)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(date)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.left")
                .foregroundStyle(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
