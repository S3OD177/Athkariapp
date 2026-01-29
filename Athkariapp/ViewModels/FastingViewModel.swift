import SwiftUI
import CoreLocation
import Combine

@MainActor
class FastingViewModel: ObservableObject {
    @Published var fastingTimes: FastingTimes?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var cityName: String = ""
    
    // Timer
    @Published var timeRemainingString: String = "00:00:00"
    @Published var remainingProgress: Double = 0.0
    @Published var timerTitle: String = "الوقت المتبقي"
    
    // Upcoming Fasting Days
    @Published var upcomingFastingDays: [FastingDayItem] = []
    
    // Service
    private let fastingService: FastingServiceProtocol
    private let prayerTimeService: PrayerTimeService
    private let locationService: LocationService
    private var timer: AnyCancellable?
    
    // Static Calendar for calculations
    private let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
    private let gregorianCalendar = Calendar(identifier: .gregorian)
    
    init(
        fastingService: FastingServiceProtocol = FastingService(),
        prayerTimeService: PrayerTimeService = PrayerTimeService(),
        locationService: LocationService
    ) {
        self.fastingService = fastingService
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        
        setupTimer()
        calculateUpcomingFastingDays()
    }
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        guard let coordinate = locationService.currentLocation else {
            isLoading = false
            errorMessage = "يرجى تفعيل الموقع"
            return
        }
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        fetchCityName(location)
        
        do {
            // 1. Fetch API data mainly for Hijri Date & White Days
            // Note: We intentionally run this in parallel or sequence. 
            // Since we need both to be consistent, we'll fetch both APIs.
            
            async let fastingTask = fastingService.fetchFastingTimes(latitude: coordinate.latitude, longitude: coordinate.longitude)
            async let prayerTask = prayerTimeService.fetchPrayerTimes(latitude: coordinate.latitude, longitude: coordinate.longitude, method: 4) // 4 = UmmAlQura
            
            let (apiTimes, prayerTimes) = try await (fastingTask, prayerTask)
            
            // 3. Sync: Use Prayer Times for Suhoor (Fajr) and Iftar (Maghrib)
            // This ensures exact match with the Prayer Times view which also uses this API.
            let syncedTimes = FastingTimes(
                date: apiTimes.date,
                suhoor: prayerTimes.fajr,
                iftar: prayerTimes.maghrib,
                hijriDate: apiTimes.hijriDate
            )
            
            self.fastingTimes = syncedTimes
            self.isLoading = false
            self.updateTimer()
            self.calculateUpcomingFastingDays()
            
        } catch {
            self.isLoading = false
            self.errorMessage = "حدث خطأ في تحميل البيانات"
            print(error)
        }
    }
    
    private func fetchCityName(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let placemark = placemarks?.first, error == nil else { return }
            
            DispatchQueue.main.async {
                self.cityName = placemark.locality ?? placemark.administrativeArea ?? ""
            }
        }
    }
    
    private func setupTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                self?.updateTimer()
            }
    }
    
    private func updateTimer() {
        guard let times = fastingTimes else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Determine Current State
        // 1. Before Suhoor? -> Target: Suhoor
        // 2. Between Suhoor & Iftar? -> Target: Iftar
        // 3. After Iftar? -> Target: Next Suhoor
        
        var targetDate: Date
        var totalDuration: TimeInterval
        // var elapsed: TimeInterval // Unused warning
        
        if now < times.suhoor {
            // Case 1: Before Suhoor
            targetDate = times.suhoor
            timerTitle = "الوقت المتبقي للإمساك"
            totalDuration = 3600 * 6 // Arbitrary
            // elapsed = targetDate.timeIntervalSince(now)
            
        } else if now >= times.suhoor && now < times.iftar {
            // Case 2: Fasting
            targetDate = times.iftar
            timerTitle = "الوقت المتبقي للإفطار"
            totalDuration = times.iftar.timeIntervalSince(times.suhoor)
            // elapsed = now.timeIntervalSince(times.suhoor)
            
        } else {
            // Case 3: After Iftar
            targetDate = calendar.date(byAdding: .day, value: 1, to: times.suhoor)!
            timerTitle = "الوقت المتبقي للإمساك"
            totalDuration = targetDate.timeIntervalSince(times.iftar)
            // elapsed = now.timeIntervalSince(times.iftar)
        }
        
        let remaining = targetDate.timeIntervalSince(now)
        
        if remaining > 0 {
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            let s = Int(remaining) % 60
            timeRemainingString = String(format: "%02d:%02d:%02d", h, m, s)
            
             remainingProgress = min(max(remaining / totalDuration, 0.0), 1.0)
            
        } else {
            timeRemainingString = "00:00:00"
            remainingProgress = 0
        }
    }
    
    private func calculateUpcomingFastingDays() {
        var events: [FastingDayItem] = []
        let today = Date()
        
        // 1. Mondays & Thursdays
        if let nextMon = nextWeekday(2, from: today) {
             events.append(FastingDayItem(title: "صيام الاثنين", subtitle: nil, date: nextMon, isConfirmed: false))
        }
        if let nextThu = nextWeekday(5, from: today) {
             events.append(FastingDayItem(title: "صيام الخميس", subtitle: nil, date: nextThu, isConfirmed: false))
        }
        
        // 2. White Days
        var hYear: Int?
        var hMonth: Int?
        var hDay: Int?
        
        if let apiHijri = fastingTimes?.hijriDate, 
           let components = parseHijriString(apiHijri) {
            hYear = components.year
            hMonth = components.month
            hDay = components.day
        } else {
            let components = hijriCalendar.dateComponents([.year, .month, .day], from: today)
            hYear = components.year
            hMonth = components.month
            hDay = components.day
        }
        
        if let year = hYear, let month = hMonth, let day = hDay {
             for targetDay in [13, 14, 15] {
                 if targetDay > day {
                     let dayDiff = targetDay - day
                     if let date = gregorianCalendar.date(byAdding: .day, value: dayDiff, to: today) {
                         events.append(FastingDayItem(title: "الأيام البيض", subtitle: "\(targetDay) \(hijriMonthName(month))", date: date, isConfirmed: false))
                     }
                 } else if targetDay == day {
                      events.append(FastingDayItem(title: "الأيام البيض", subtitle: "\(targetDay) \(hijriMonthName(month))", date: today, isConfirmed: false))
                 }
             }
             
             if events.count < 3 {
                 let nextMonth = month == 12 ? 1 : month + 1
                 let nextYear = month == 12 ? year + 1 : year
                 
                 for d in [13, 14, 15] {
                     if let date = hijriCalendar.date(from: DateComponents(year: nextYear, month: nextMonth, day: d)) {
                          events.append(FastingDayItem(title: "الأيام البيض", subtitle: "\(d) \(hijriMonthName(nextMonth))", date: date, isConfirmed: false))
                     }
                 }
             }
        }
        
        upcomingFastingDays = events.sorted(by: { $0.date < $1.date }).prefix(4).map { $0 }
    }
    
    private func parseHijriString(_ dateStr: String) -> (year: Int, month: Int, day: Int)? {
        let parts = dateStr.components(separatedBy: "-")
        if parts.count == 3, 
           let y = Int(parts[0]), 
           let m = Int(parts[1]), 
           let d = Int(parts[2]) {
            return (y, m, d)
        }
        return nil
    }
    
    private func nextWeekday(_ weekday: Int, from date: Date) -> Date? {
        let currentWeekday = gregorianCalendar.component(.weekday, from: date)
        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 { daysToAdd += 7 }
        return gregorianCalendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
    
    private func hijriMonthName(_ month: Int) -> String {
        let months = [
            1: "محرم", 2: "صفر", 3: "ربيع الأول", 4: "ربيع الثاني",
            5: "جمادى الأولى", 6: "جمادى الآخرة", 7: "رجب", 8: "شعبان",
            9: "رمضان", 10: "شوال", 11: "ذو القعدة", 12: "ذو الحجة"
        ]
        return months[month] ?? ""
    }
}

struct FastingDayItem: Identifiable {
    let id = UUID()
    let title: String
    var subtitle: String? = nil
    let date: Date
    var isConfirmed: Bool
}
