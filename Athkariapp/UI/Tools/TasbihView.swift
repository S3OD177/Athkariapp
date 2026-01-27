import SwiftUI

@MainActor
@Observable
final class TasbihViewModel {
    var count: Int = 0
    var target: Int = 33
    var customTarget: Int? // For custom entries
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
    
    // History Logic
    var history: [(date: Date, count: Int, dhikr: String)] = []
    
    // Dependencies
    private let hapticsService = HapticsService.shared
    
    func increment() {
        // Prevent counting past target if desired, or just loop/notify
        // Here we notify on completion but allow continuous counting if user wants, 
        // OR we can cap it. Let's strictly follow target logic:
        if count < target {
            count += 1
            if count == target {
                if isHapticsEnabled {
                    hapticsService.playNotification(.success)
                }
            } else {
                if isHapticsEnabled {
                   hapticsService.playImpact(.light)
                }
            }
        } else {
            // Already reached target. User tapped again.
            // Reset automatically? Or just bounce? 
            // Let's reset for continuous flow like a real misbaha
            addToHistory()
            count = 1
            if isHapticsEnabled {
                hapticsService.playImpact(.light)
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
        customTarget = nil // Clear custom if picking standard
        // Reset count if target changed? Usually yes.
        count = 0
    }
    
    func setCustomTarget(_ val: Int) {
        target = val
        customTarget = val
        count = 0
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
                // Header - Swapped Buttons as requested (X Left/Leading, History Right/Trailing)
                HStack {
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
                    
                    Spacer()
                    
                    Text("المسبحة الإلكترونية")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Active Dhikr Title
                Text(viewModel.currentDhikr)
                    .font(.title) // Increased size
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 32)
                
                // Target Pill
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption)
                        Text("الهدف: \(viewModel.target)")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(AppColors.onboardingPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.onboardingPrimary.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.onboardingPrimary.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .padding(.top, 16)
                
                Spacer()
                
                // Main Counter Ring
                CounterCircle(
                    currentCount: viewModel.count,
                    targetCount: viewModel.target,
                    size: 280,
                    activeColor: AppColors.onboardingPrimary
                ) {
                    viewModel.increment()
                }
                
                Text("المس الدائرة للتسبيح")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.top, 24)
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 24) { // Increased spacing
                    // Toggle Haptics
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
                        .frame(width: 70, height: 70) // Slightly smaller
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                    }
                    
                    // Change Dhikr (Prominent)
                    Button {
                        showDhikrList = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                            Text("تغيير الذكر")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(Circle())
                        .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
                    }
                    
                    // Reset
                    Button {
                        viewModel.reset()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                            Text("تصفير")
                                .font(.caption2)
                        }
                        .foregroundStyle(.gray)
                        .frame(width: 70, height: 70)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showSettings) {
             TasbihSettingsSheet(viewModel: viewModel)
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
    @Bindable var viewModel: TasbihViewModel
    @State private var customTargetText = ""
    @FocusState private var isCustomFocused: Bool
    
    let targets = [33, 100, 1000]
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("تحديد الهدف")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 24)
                
                // Presets
                ForEach(targets, id: \.self) { val in
                    Button {
                        viewModel.updateTarget(val)
                        dismiss()
                    } label: {
                        HStack {
                            Text("\(val)")
                                .font(.body.bold())
                            Spacer()
                            if viewModel.target == val && viewModel.customTarget == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColors.onboardingPrimary)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(AppColors.onboardingSurface)
                        .cornerRadius(12)
                    }
                }
                
                // Custom Target Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("هدف مخصص")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 4)
                        
                    HStack {
                        TextField("أدخل الرقم", text: $customTargetText)
                            .keyboardType(.numberPad)
                            .focused($isCustomFocused)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .foregroundStyle(.white)
                        
                        Button {
                            // Save custom
                            if let val = Int(customTargetText), val > 0 {
                                viewModel.setCustomTarget(val)
                                dismiss()
                            }
                        } label: {
                            Text("حفظ")
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(AppColors.onboardingPrimary)
                                .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .onAppear {
            if let custom = viewModel.customTarget {
                customTargetText = "\(custom)"
            }
        }
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
                        .foregroundStyle(.gray)
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
