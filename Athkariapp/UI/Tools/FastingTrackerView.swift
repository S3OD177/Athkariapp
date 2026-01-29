import SwiftUI
import Charts

struct FastingTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container
    @StateObject private var viewModel: FastingViewModel
    
    // Calendar Grid State
    @State private var showHijriCalendar = false
    
    // Calendar Grid State
    // (Removed static grid state)
    
    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: FastingViewModel(
            fastingService: FastingService(), // explicitly call if needed or let default handle it, but wait, signature has defaults.
            // Argument order: fastingService, prayerTimeService, locationService
            // fastingService has default.
            prayerTimeService: container.prayerTimeService,
            locationService: container.locationService
        ))
    }
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
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
                    
                    Text("متابع الصيام")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        showHijriCalendar = true
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                        .padding(.bottom, 8)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // MARK: - Hero Timer Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(AppColors.sessionSurface)
                            
                            VStack(spacing: 24) {
                                // Date Header
                                VStack(spacing: 4) {
                                    Text(viewModel.cityName)
                                        .font(.caption.bold())
                                        .foregroundStyle(AppColors.onboardingPrimary)
                                    
                                    Text(viewModel.fastingTimes?.hijriDate ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textGray)
                                }
                                
                                Text(viewModel.timerTitle)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                // Circular Timer
                                ZStack {
                                    // Track
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 15)
                                    
                                    // Progress
                                    Circle()
                                        .trim(from: 0, to: viewModel.remainingProgress)
                                        .stroke(
                                            AppColors.onboardingPrimary,
                                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear(duration: 1.0), value: viewModel.remainingProgress)
                                    
                                    // Time Text
                                    VStack(spacing: 4) {
                                        Text(viewModel.timeRemainingString)
                                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .environment(\.locale, Locale(identifier: "en")) 
                                        
                                        Text("ساعة : دقيقة : ثانية")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textGray)
                                    }
                                }
                                .frame(width: 220, height: 220)
                                
                                // Times Grid
                                HStack(spacing: 16) {
                                    InfoBox(
                                        title: "الإمساك",
                                        time: viewModel.fastingTimes?.suhoor.formatted(date: .omitted, time: .shortened) ?? "--:--"
                                    )
                                    
                                    InfoBox(
                                        title: "الإفطار",
                                        time: viewModel.fastingTimes?.iftar.formatted(date: .omitted, time: .shortened) ?? "--:--"
                                    )
                                }
                            }
                            .padding(24)
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Upcoming Fasting
                        VStack(alignment: .leading, spacing: 16) {
                            Text("صيام القادم")
                                .font(.headline)
                                .foregroundStyle(AppColors.onboardingPrimary)
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.upcomingFastingDays) { item in
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.onboardingPrimary.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "sun.max.fill")
                                                .foregroundStyle(AppColors.onboardingPrimary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            
                                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textGray)
                                        }
                                        
                                        Spacer()
                                        
                                        // Removed Toggle
                                    }
                                    .padding(16)
                                    .background(AppColors.sessionSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Removed Logic / Static Calendar Section
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showHijriCalendar) {
            HijriCalendarView()
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct InfoBox: View {
    let title: String
    let time: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textGray)
            
            Text(time)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
