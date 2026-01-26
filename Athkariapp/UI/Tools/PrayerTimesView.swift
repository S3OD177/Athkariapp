import SwiftUI
import CoreLocation

@MainActor
@Observable
final class PrayerViewModel {
    var prayerTimes: [PrayerDisplayItem] = []
    var timeRemaining: String = "٠٠:٠٠:٠٠"
    var nextPrayerName: String = ""
    var locationName: String = ""
    var hijriDate: String = ""
    var isLoading = false
    
    private let prayerTimeService: PrayerTimeService
    private let locationService: LocationService
    nonisolated(unsafe) private var timer: Timer?
    private var currentTimes: PrayerTimes?
    
    struct PrayerDisplayItem: Identifiable {
        let id = UUID()
        let prayer: Prayer
        let name: String
        let time: String
        let icon: String
        var isActive: Bool = false
    }
    
    init(prayerTimeService: PrayerTimeService, locationService: LocationService) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        self.locationName = "جاري تحديد الموقع..."
        self.hijriDate = Date().formatHijri()
    }
    
    func loadData() async {
        isLoading = true
        
        // Use existing location if available, otherwise start updating
        if let location = locationService.currentLocation {
            await fetchTimes(for: location)
        } else {
            locationService.startUpdatingLocation()
            // Bind to location updates
            locationService.onLocationUpdate = { [weak self] coord in
                Task { @MainActor in
                    await self?.fetchTimes(for: coord)
                }
            }
            
            // Fallback to default
            let times = prayerTimeService.getDefaultPrayerTimes()
            updateWithTimes(times)
        }
        
        isLoading = false
        startTimer()
    }
    
    private func fetchTimes(for location: CLLocationCoordinate2D) async {
        do {
            let times = try await prayerTimeService.fetchPrayerTimes(
                latitude: location.latitude,
                longitude: location.longitude
            )
            updateWithTimes(times)
            locationName = "موقعك الحالي"
        } catch {
            print("Error fetching prayer times: \(error)")
        }
    }
    
    private func updateWithTimes(_ times: PrayerTimes) {
        self.currentTimes = times
        let currentAdhan = times.currentAdhan()
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "ar_SA")
        
        prayerTimes = Prayer.allCases.map { prayer in
            let time: Date
            switch prayer {
            case .fajr: time = times.fajr
            case .sunrise: time = times.sunrise
            case .dhuhr: time = times.dhuhr
            case .asr: time = times.asr
            case .maghrib: time = times.maghrib
            case .isha: time = times.isha
            }
            
            return PrayerDisplayItem(
                prayer: prayer,
                name: prayer.arabicName,
                time: formatter.string(from: time).replacingOccurrences(of: "ص", with: "ص").replacingOccurrences(of: "م", with: "م"),
                icon: prayer.icon,
                isActive: prayer == currentAdhan
            )
        }
        
        if let next = times.nextPrayer() {
            nextPrayerName = next.prayer.arabicName
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdown()
            }
        }
    }
    
    private func updateCountdown() {
        guard let times = currentTimes, let next = times.nextPrayer() else { return }
        
        let remaining = next.time.timeIntervalSince(Date())
        if remaining <= 0 {
            // Refresh times if prayer started
            Task { await loadData() }
            return
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds).arabicNumeral
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct PrayerTimesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container
    @State private var viewModel: PrayerViewModel?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                PrayerTimesContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = PrayerViewModel(
                            prayerTimeService: container.prayerTimeService,
                            locationService: container.locationService
                        )
                    }
            }
        }
    }
}

struct PrayerTimesContent: View {
    @Bindable var viewModel: PrayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        // More options
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("مواقيت الصلاة")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero Card: Countdown
                        ZStack {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "FEF3C7"), Color(hex: "FFFBEB")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("تبقى لصلاة \(viewModel.nextPrayerName)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color(hex: "92400E"))
                                    
                                    Text(viewModel.timeRemaining)
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "1F2937"))
                                        .contentTransition(.numericText())
                                    
                                    Button {
                                        // Toggle alert
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "bell.fill")
                                            Text("تنبيه الصلاة")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(AppColors.onboardingPrimary)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                    }
                                }
                                
                                Spacer()
                                
                                // Sun/Icon
                                ZStack {
                                    Circle()
                                        .fill(AppColors.onboardingPrimary.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(AppColors.onboardingPrimary)
                                }
                            }
                            .padding(32)
                        }
                        .frame(height: 200)
                        
                        // Section Header
                        HStack {
                            Text("مواعيد اليوم")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(viewModel.hijriDate)
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 8)
                        
                        // Prayer Times List
                        VStack(spacing: 12) {
                            ForEach(viewModel.prayerTimes) { prayer in
                                PrayerRow(prayer: prayer)
                            }
                        }
                        
                        // Location Footer
                        HStack {
                            Spacer()
                            Text(viewModel.locationName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.gray)
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(AppColors.onboardingPrimary)
                        }
                        .padding(.top, 8)
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct PrayerRow: View {
    let prayer: PrayerViewModel.PrayerDisplayItem
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(prayer.isActive ? AppColors.onboardingPrimary : Color.white.opacity(0.05))
                    .frame(width: 48, height: 48)
                
                Image(systemName: prayer.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(prayer.isActive ? .white : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(prayer.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(prayer.isActive ? .white : .gray)
                
                if prayer.isActive {
                    Text("الآن")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.onboardingPrimary)
                }
            }
            
            Spacer()
            
            Text(prayer.time)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(prayer.isActive ? .white : .gray)
        }
        .padding(16)
        .background(prayer.isActive ? AppColors.onboardingSurface : Color.white.opacity(0.02))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(prayer.isActive ? AppColors.onboardingPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
