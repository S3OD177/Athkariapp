import SwiftUI

@MainActor
@Observable
final class TasbihViewModel {
    var count: Int = 0
    var target: Int = 33
    var currentDhikr: String = "سبحان الله"
    var isHapticsEnabled: Bool = true
    
    // Dhikr Preset List
    let dhikrList = [
        "سبحان الله",
        "الحمد لله",
        "الله أكبر",
        "لا إله إلا الله",
        "أستغفر الله",
        "اللهم صل على محمد"
    ]
    
    // History Logic (Simple in-memory for now)
    var history: [(date: Date, count: Int, dhikr: String)] = []
    
    // Dependencies
    private let hapticsService = HapticsService.shared
    
    func increment() {
        count += 1
        if isHapticsEnabled {
            hapticsService.playImpact(.light)
        }
        
        if count % target == 0 {
            if isHapticsEnabled {
                hapticsService.playNotification(.success)
            }
        }
    }
    
    func reset() {
        if count > 0 {
            addToHistory()
        }
        count = 0
        if isHapticsEnabled {
            hapticsService.playImpact(.medium)
        }
    }
    
    private func addToHistory() {
        history.insert((Date(), count, currentDhikr), at: 0)
        // Keep last 20 entries
        if history.count > 20 {
            history.removeLast()
        }
    }
    
    func toggleHaptics() {
        isHapticsEnabled.toggle()
        if isHapticsEnabled {
            hapticsService.playImpact(.light)
        }
    }
    
    func updateDhikr(_ text: String) {
        if count > 0 {
            addToHistory()
            count = 0
        }
        currentDhikr = text
    }
    
    func updateTarget(_ newTarget: Int) {
        target = newTarget
    }
}

struct TasbihView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TasbihViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showDhikrList = false
    
    var body: some View {
        ZStack {
            // Background
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("المسبحة الإلكترونية")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Target Pill
                Button {
                    showSettings = true
                } label: {
                    Text("الهدف: \(viewModel.target)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.onboardingPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(AppColors.onboardingPrimary.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(AppColors.onboardingPrimary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Main Counter Area
                Button {
                    viewModel.increment()
                } label: {
                    VStack(spacing: 24) {
                        Text(viewModel.currentDhikr)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("\(viewModel.count)")
                            .font(.system(size: 96, weight: .bold))
                            .foregroundStyle(AppColors.onboardingPrimary)
                            .contentTransition(.numericText(value: Double(viewModel.count)))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Text("المس في أي مكان للتسبيح")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.bottom, 40)
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 16) {
                    Button {
                        viewModel.toggleHaptics()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.isHapticsEnabled ? "iphone.gen3.radiowaves.left.and.right" : "iphone.slash")
                                .font(.system(size: 20))
                            Text("الاهتزاز")
                                .font(.caption2)
                        }
                        .foregroundStyle(viewModel.isHapticsEnabled ? AppColors.onboardingPrimary : .gray)
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                    }
                    
                    Button {
                        showDhikrList = true
                    } label: {
                        HStack {
                            Text("تغيير الذكر")
                                .font(.headline)
                            Image(systemName: "arrow.left.arrow.right")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(Capsule())
                        .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
                    }
                    
                    Button {
                        viewModel.reset()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                            Text("إعادة ضبط")
                                .font(.caption2)
                        }
                        .foregroundStyle(.gray)
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showSettings) {
             TasbihSettingsSheet(target: $viewModel.target)
        }
        .sheet(isPresented: $showHistory) {
            TasbihHistorySheet(history: viewModel.history)
        }
        .sheet(isPresented: $showDhikrList) {
            TasbihDhikrSheet(selectedDhikr: $viewModel.currentDhikr, dhikrList: viewModel.dhikrList) { newDhikr in
                viewModel.updateDhikr(newDhikr)
            }
        }
    }
}

// MARK: - Sub-sheets

struct TasbihSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: Int
    
    let targets = [33, 100, 1000, 10000]
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("تحديد الهدف")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 24)
                
                ForEach(targets, id: \.self) { val in
                    Button {
                        target = val
                        dismiss()
                    } label: {
                        HStack {
                            Text("\(val)")
                                .font(.body)
                            Spacer()
                            if target == val {
                                Image(systemName: "checkmark")
                            }
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(AppColors.onboardingSurface)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}

struct TasbihHistorySheet: View {
    let history: [(date: Date, count: Int, dhikr: String)]
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            VStack {
                Text("سجل التسبيح")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(24)
                
                if history.isEmpty {
                    Spacer()
                    ContentUnavailableView("لا يوجد سجل", systemImage: "clock", description: Text("ابدأ التسبيح وسوف يظهر سجلك هنا"))
                    Spacer()
                } else {
                    List(history, id: \.date) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.dhikr)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Text("\(item.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.onboardingPrimary)
                        }
                        .listRowBackground(AppColors.onboardingSurface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TasbihDhikrSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDhikr: String
    let dhikrList: [String]
    var onSelect: (String) -> Void
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            VStack {
                Text("اختر الذكر")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(24)
                
                List(dhikrList, id: \.self) { dhikr in
                    Button {
                        onSelect(dhikr)
                        dismiss()
                    } label: {
                        HStack {
                            Text(dhikr)
                                .font(.body)
                                .foregroundStyle(.white)
                            Spacer()
                            if selectedDhikr == dhikr {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColors.onboardingPrimary)
                            }
                        }
                    }
                    .listRowBackground(AppColors.onboardingSurface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .presentationDetents([.medium])
    }
}
