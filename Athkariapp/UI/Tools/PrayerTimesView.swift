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
        
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
        }
        
        // Use existing location if available, otherwise start updating
        if let location = locationService.currentLocation {
            await fetchTimes(for: location)
        } else {
            locationService.startUpdatingLocation()
            // Bind to location updates
            locationService.onLocationUpdate = { [weak self] coord in
                Task { @MainActor in
                    await self?.fetchTimes(for: coord)
                    self?.locationService.stopUpdatingLocation()
                    self?.locationService.onLocationUpdate = nil
                }
            }
            
            // Fallback to default
            let times = prayerTimeService.getDefaultPrayerTimes()
            updateWithTimes(times)
        }
        
        isLoading = false
    }
    
    private func fetchTimes(for location: CLLocationCoordinate2D) async {
        do {
            let times = try await prayerTimeService.fetchPrayerTimes(
                latitude: location.latitude,
                longitude: location.longitude
            )
            updateWithTimes(times)
            
            // Reverse geocode to get city name
            await fetchCityName(for: location)
        } catch {
            print("Error fetching prayer times: \(error)")
            // Fallback to manual calculation
            let times = prayerTimeService.getPrayerTimes(
                date: Date(),
                location: location,
                method: .ummAlQura
            )
            updateWithTimes(times)
            locationName = "حساب محلي (تعذر الاتصال)"
        }
    }
    
    private func fetchCityName(for location: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            if let placemark = placemarks.first {
                // Prefer locality (city), then administrativeArea, then country
                let city = placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "موقعك الحالي"
                locationName = city
            }
        } catch {
            print("Geocoding error: \(error)")
            locationName = "موقعك الحالي"
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
    
    func startTicker() async {
        while !Task.isCancelled {
            await updateCountdown()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    private func updateCountdown() async {
        guard let times = currentTimes else { return }
        
        var nextTime: Date
        
        if let next = times.nextPrayer() {
            nextTime = next.time
            nextPrayerName = next.prayer.arabicName
        } else {
            // If no next prayer (passed Isha), next is tomorrow's Fajr
            // Approximate by adding 24 hours to today's Fajr
            nextTime = times.fajr.addingTimeInterval(86400) // 24 hours
            nextPrayerName = Prayer.fajr.arabicName
        }
        
        let remaining = nextTime.timeIntervalSince(Date())
        if remaining <= 0 {
            // Refresh times if prayer started (or if we drifted past Fajr next day)
            await loadData()
            return
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
            
            // Ambient Background
            AmbientBackground()
                .opacity(0.5)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.right") // RTL
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            )
                    }
                    
                    Spacer()
                    
                    Text("مواقيت الصلاة")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Empty spacer for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero Card: Countdown
                        ZStack {
                            // Background
                            RoundedRectangle(cornerRadius: 32)
                                .fill(AppColors.sessionSurface)
                            
                            // Gold Gradient Overlay
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
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            AppColors.onboardingPrimary.opacity(0.15),
                                            AppColors.sessionBackground.opacity(0)
                                        ]),
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 200
                                    ),
                                    lineWidth: 1
                                )
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(AppColors.onboardingPrimary)
                                            .frame(width: 6, height: 6)
                                        
                                        Text("الصلاة القادمة")
                                            .font(.caption.bold())
                                            .foregroundStyle(AppColors.onboardingPrimary)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                    }
                                    
                                    Text(viewModel.nextPrayerName)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(.white)
                                    
                                    Text(viewModel.timeRemaining)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .contentTransition(.numericText())
                                        .padding(.top, 4)
                                    
                                    // Location
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.caption)
                                        Text(viewModel.locationName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(AppColors.textGray)
                                    .padding(.top, 8)
                                }
                                
                                Spacer()
                                
                                // Decorative Icon
                                ZStack {
                                    Circle()
                                        .stroke(AppColors.onboardingPrimary.opacity(0.4), lineWidth: 1)
                                        .frame(width: 80, height: 80)
                                        .blur(radius: 20)
                                    
                                    Image(systemName: "sun.max.fill") // Could vary based on prayer
                                        .font(.system(size: 40))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [AppColors.onboardingPrimary, .orange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            }
                            .padding(24)
                        }
                        .frame(height: 200)
                        .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
                        
                        // Section Header
                        HStack {
                            Text("مواعيد اليوم")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(viewModel.hijriDate)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.onboardingPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.onboardingPrimary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 4)
                        
                        // Prayer Times List
                        VStack(spacing: 12) {
                            ForEach(viewModel.prayerTimes) { prayer in
                                PrayerRow(prayer: prayer)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .task {
            // Start data loading and ticker concurrently
            await viewModel.loadData()
        }
        .task {
             await viewModel.startTicker()
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
                    .frame(width: 44, height: 44)
                
                Image(systemName: prayer.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(prayer.isActive ? .white : AppColors.textGray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(prayer.name)
                    .font(.headline)
                    .foregroundStyle(prayer.isActive ? .white : .white.opacity(0.8))
                
                if prayer.isActive {
                    Text("الصلاة الحالية")
                        .font(.caption2.bold())
                        .foregroundStyle(prayer.isActive ? AppColors.onboardingPrimary.opacity(0.8) : .white)
                }
            }
            
            Spacer()
            
            Text(prayer.time)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(prayer.isActive ? AppColors.onboardingPrimary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(prayer.isActive ? AppColors.onboardingPrimary.opacity(0.1) : Color.white.opacity(0.05))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.sessionSurface) // Lighter than bg
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    prayer.isActive ? AppColors.onboardingPrimary.opacity(0.5) : Color.white.opacity(0.03),
                    lineWidth: 1
                )
        )
        .scaleEffect(prayer.isActive ? 1.02 : 1.0)
        .shadow(color: prayer.isActive ? AppColors.onboardingPrimary.opacity(0.1) : Color.clear, radius: 10)
    }
}
