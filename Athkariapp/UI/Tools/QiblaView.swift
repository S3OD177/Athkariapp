import SwiftUI
import CoreLocation

@MainActor
@Observable
final class QiblaViewModel {
    // MARK: - Published State
    var heading: Double = 0
    var qiblaDirection: Double = 0
    var locationPermissionGranted: Bool = false
    var locationError: String?
    
    // Kaaba location
    private let kaabaLatitude = 21.4225
    private let kaabaLongitude = 39.8262
    
    // MARK: - Dependencies
    private let locationService: LocationService
    
    init(locationService: LocationService) {
        self.locationService = locationService
        setupBindings()
    }
    
    // Note: Cleanup handled by QiblaContent.onDisappear calling stopUpdating()
    
    // MARK: - Public Methods
    func startUpdating() {
        locationService.requestPermission()
        checkPermission()
        
        if locationPermissionGranted {
            locationService.startUpdatingLocation()
            locationService.startUpdatingHeading()
        }
    }
    
    func stopUpdating() {
        locationService.stopUpdatingHeading()
        locationService.stopUpdatingLocation()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Handle authorization changes
        locationService.onAuthorizationChange = { [weak self] status in
            self?.handleAuthStatus(status)
        }
        
        locationService.onLocationUpdate = { [weak self] coordinate in
            self?.calculateQiblaDirection(current: coordinate)
        }
        
        locationService.onHeadingUpdate = { [weak self] newHeading in
            self?.heading = newHeading
        }
        
        // Initial check
        checkPermission()
    }
    
    private func checkPermission() {
        handleAuthStatus(locationService.authorizationStatus)
    }
    
    private func handleAuthStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationPermissionGranted = true
            locationError = nil
            locationService.startUpdatingLocation()
            locationService.startUpdatingHeading()
        case .denied, .restricted:
            locationPermissionGranted = false
            locationError = "الرجاء تفعيل خدمات الموقع لتحديد القبلة"
        case .notDetermined:
            locationPermissionGranted = false
            locationError = nil
        @unknown default:
            break
        }
    }
    
    private func calculateQiblaDirection(current: CLLocationCoordinate2D) {
        let phiK = kaabaLatitude * .pi / 180.0
        let lambdaK = kaabaLongitude * .pi / 180.0
        let phi = current.latitude * .pi / 180.0
        let lambda = current.longitude * .pi / 180.0
        
        let psi = 180.0 / .pi * atan2(
            sin(lambdaK - lambda),
            cos(phi) * tan(phiK) - sin(phi) * cos(lambdaK - lambda)
        )
        
        qiblaDirection = psi
    }
    
    var offsetAngle: Double {
        return qiblaDirection
    }
    
    var isAligned: Bool {
        let diff = abs(heading - qiblaDirection)
        return diff < 5 || diff > 355
    }
}

struct QiblaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container
    @State private var viewModel: QiblaViewModel?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                QiblaContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }
    
    private func setupViewModel() {
        viewModel = QiblaViewModel(locationService: container.locationService)
    }
}

struct QiblaContent: View {
    @Bindable var viewModel: QiblaViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.homeBackground.ignoresSafeArea()
                
                VStack(spacing: geometry.size.height * 0.04) {
                    // Header
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
                        
                        Text("اتجاه القبلة")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Empty space for balance
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    if !viewModel.locationPermissionGranted {
                        permissionState
                    } else {
                        compassState(geometry: geometry)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startUpdating()
        }
        .onDisappear {
            viewModel.stopUpdating()
        }
    }
    
    // MARK: - Permission State
    private var permissionState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "location.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.gray)
                .padding(32)
                .background(Color.white.opacity(0.05))
                .clipShape(Circle())
            
            Text("نحتاج إذن الوصول للموقع")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("لتحديد اتجاه القبلة بدقة، يرجى السماح للتطبيق بالوصول إلى موقعك الحالي.")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                viewModel.startUpdating()
            } label: {
                Text("تفعيل الموقع")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(height: 50)
                    .padding(.horizontal, 40)
                    .background(AppColors.onboardingPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            if let error = viewModel.locationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Compass State
    private func compassState(geometry: GeometryProxy) -> some View {
        VStack(spacing: geometry.size.height * 0.04) {
            // Compass Degree
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 4) {
                    Text("\(Int(viewModel.heading))")
                        .font(.system(size: geometry.size.width * 0.15, weight: .heavy))
                    Text("°")
                        .font(.system(size: geometry.size.width * 0.08, weight: .bold))
                        .offset(y: 12)
                }
                .foregroundStyle(viewModel.isAligned ? AppColors.onboardingPrimary : .white)
                .animation(.easeInOut, value: viewModel.isAligned)
                
                Text(viewModel.isAligned ? "باتجاه القبلة" : "ابحث عن القبلة")
                    .font(.system(size: 16))
                    .foregroundStyle(viewModel.isAligned ? AppColors.onboardingPrimary : .gray)
            }
            
            // Compass Visual
            let compassSize = geometry.size.width * 0.8
            ZStack {
                // Outer Ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: compassSize, height: compassSize)
                
                // Rotating Compass Content
                ZStack {
                    // Major Points
                    ForEach(0..<12) { i in
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 2, height: 8)
                            .offset(y: -(compassSize / 2 - 10))
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    
                    // Minor Points
                    ForEach(0..<36) { i in
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 4, height: 4)
                            .offset(y: -(compassSize / 2 - 10))
                            .rotationEffect(.degrees(Double(i) * 10))
                    }
                    
                    // North Indicator
                    Text("N")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.red)
                        .offset(y: -(compassSize / 2 - 30))
                    
                    // Qibla Indicator (Kaaba)
                    // We rotate this indicator relative to North based on logic bearing
                    let qiblaOffset = viewModel.offsetAngle
                    ZStack {
                        Circle()
                            .stroke(viewModel.isAligned ? AppColors.onboardingPrimary : AppColors.onboardingPrimary.opacity(0.3), lineWidth: 3)
                            .frame(width: compassSize * 0.85, height: compassSize * 0.85)
                        
                        VStack(spacing: 0) {
                            Image(systemName: "kaaba") // If custom symbol exists, otherwise mosque
                                .symbolVariant(.fill)
                                .font(.system(size: 20))
                                .foregroundStyle(viewModel.isAligned ? AppColors.onboardingPrimary : AppColors.onboardingPrimary.opacity(0.5))
                            
                            Rectangle()
                                .fill(viewModel.isAligned ? AppColors.onboardingPrimary : AppColors.onboardingPrimary.opacity(0.3))
                                .frame(width: 2, height: compassSize * 0.35)
                        }
                        .offset(y: -(compassSize * 0.17))
                    }
                    .rotationEffect(.degrees(qiblaOffset))
                }
                .rotationEffect(.degrees(-viewModel.heading)) // Rotate everything opposite to device heading
                .animation(.linear(duration: 0.1), value: viewModel.heading) // Smooth updates
                
                // Center Mosque Circle (Fixed)
                ZStack {
                    Circle()
                        .fill(Color(hex: "FFF9F2").opacity(0.9))
                        .frame(width: geometry.size.width * 0.2, height: geometry.size.width * 0.2)
                    
                    Image(systemName: "mosque.fill")
                        .font(.system(size: geometry.size.width * 0.08))
                        .foregroundStyle(viewModel.isAligned ? AppColors.onboardingPrimary : AppColors.onboardingPrimary.opacity(0.3))
                }
            }
            .frame(width: compassSize, height: compassSize)
            
            if viewModel.isAligned {
                VStack(spacing: 8) {
                    Text("أنت الآن باتجاه القبلة")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.onboardingPrimary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("استجابة لمسية مفعلة")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                Spacer().frame(height: 50) // Placeholder to prevent jump
            }
            
            // Distance Card
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("المسافة إلى مكة المكرمة")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                    
                    HStack(spacing: 4) {
                        // Rough calculation placeholder or empty, 
                        // could be added to ViewModel if desired
                        Text("مكة")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                // Map Preview Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 64)
                    .overlay(
                        Image(systemName: "map.fill")
                            .foregroundStyle(.gray)
                    )
            }
            .padding(16)
            .background(AppColors.onboardingSurface)
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    QiblaView()
        .preferredColorScheme(.dark)
}
