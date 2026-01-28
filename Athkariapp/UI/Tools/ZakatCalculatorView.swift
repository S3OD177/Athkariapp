import SwiftUI

// MARK: - Zakat Service
// Embedded for scope visibility

struct ZakatRates: Codable {
    let goldPricePerGramUSD: Double
    let lastUpdated: String
    
    // Fixed conversion rate for SAR (1 USD = 3.75 SAR)
    // In a real app, you might fetch live currency rates too.
    var goldPricePerGramSAR: Double {
        goldPricePerGramUSD * 3.753 // Slightly more precise
    }
}

private struct DailyNisabResponse: Codable {
    let success: Bool
    let data: DailyNisabData
}

private struct DailyNisabData: Codable {
    let drtInUSD: Double
    let drtDate: String
}

enum ZakatServiceError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}

actor ZakatService {
    static let shared = ZakatService()
    
    private let endpoint = "https://dailynisab.org/index.php/api/v1/rates/latest"
    
    func fetchLatestRates() async throws -> ZakatRates {
        guard let url = URL(string: endpoint) else {
            throw ZakatServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ZakatServiceError.invalidResponse
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(DailyNisabResponse.self, from: data)
            guard decodedResponse.success else {
                throw ZakatServiceError.invalidResponse
            }
            
            return ZakatRates(
                goldPricePerGramUSD: decodedResponse.data.drtInUSD,
                lastUpdated: decodedResponse.data.drtDate
            )
        } catch {
            print("ZakatService Decoding Error: \(error)")
            throw ZakatServiceError.decodingError
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ZakatViewModel {
    // Inputs (as Doubles)
    var goldWeight: Double = 0
    var silverWeight: Double = 0
    var cashAmount: Double = 0
    var stocksAmount: Double = 0
    
    // Prices
    var goldPricePerGram: Double = 0 // Will initialize
    var silverPricePerGram: Double = 3.5 // Manual default
    
    // State
    var isLoading: Bool = false
    var lastUpdated: String?
    var errorMessage: String?
    var currencySymbol: String = "ريال"
    
    // Logic
    var totalAssets: Double {
        (goldWeight * goldPricePerGram) +
        (silverWeight * silverPricePerGram) +
        cashAmount +
        stocksAmount
    }
    
    // Standard Nisab is 85g of 24k Gold
    var nisabThreshold: Double {
        max(1, 85.0 * goldPricePerGram) // Prevent 0 division/issues
    }
    
    var zakatDue: Double {
        isNisabReached ? totalAssets * 0.025 : 0
    }
    
    var isNisabReached: Bool {
        totalAssets >= nisabThreshold
    }
    
    func fetchRates() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Add minimum artificial delay for UX (so user sees "refreshing" if it's too fast)
                try? await Task.sleep(for: .milliseconds(500))
                
                let rates = try await ZakatService.shared.fetchLatestRates()
                
                withAnimation {
                    self.goldPricePerGram = rates.goldPricePerGramSAR
                    self.lastUpdated = rates.lastUpdated
                    self.errorMessage = nil
                }
            } catch {
                withAnimation {
                    self.errorMessage = "فشل التحديث. تأكد من الإنترنت."
                }
            }
            self.isLoading = false
        }
    }
}

// MARK: - View

struct ZakatCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ZakatViewModel()
    @FocusState private var focusedField: Field?
    
    enum Field {
        case gold, silver, cash, stocks, goldPrice, silverPrice
    }
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Summary Card (Equatable for performance)
                        ZakatSummaryCardView(
                            zakatDue: viewModel.zakatDue,
                            isNisabReached: viewModel.isNisabReached,
                            nisabThreshold: viewModel.nisabThreshold,
                            currency: viewModel.currencySymbol
                        )
                        .drawingGroup() // Metal-accelerated rendering
                        
                        // Inputs
                        VStack(spacing: 16) {
                            sectionHeader(title: "الأصول والممتلكات", icon: "briefcase.fill")
                            
                            DebouncedInputRow(
                                title: "الذهب (جرام)",
                                value: $viewModel.goldWeight,
                                focusedField: $focusedField,
                                field: .gold,
                                icon: "circle.grid.2x2.fill",
                                color: .yellow
                            )
                            
                            DebouncedInputRow(
                                title: "الفضة (جرام)",
                                value: $viewModel.silverWeight,
                                focusedField: $focusedField,
                                field: .silver,
                                icon: "circle.circle.fill",
                                color: .gray
                            )
                             
                            DebouncedInputRow(
                                title: "السيولة النقدية",
                                value: $viewModel.cashAmount,
                                focusedField: $focusedField,
                                field: .cash,
                                icon: "banknote.fill",
                                color: .green
                            )
                            
                            DebouncedInputRow(
                                title: "أسهم واستثمارات",
                                value: $viewModel.stocksAmount,
                                focusedField: $focusedField,
                                field: .stocks,
                                icon: "chart.line.uptrend.xyaxis",
                                color: .blue
                            )
                        }
                        .padding(.horizontal)
                        
                        // Prices
                        VStack(spacing: 16) {
                            HStack {
                                sectionHeader(title: "أسعار السوق (تقديرية)", icon: "chart.bar.fill")
                                Spacer()
                                Button {
                                    viewModel.fetchRates()
                                } label: {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(AppColors.primary)
                                    } else {
                                        HStack(spacing: 4) {
                                            Text("تحديث")
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        .font(.caption.bold())
                                        .foregroundStyle(AppColors.primary)
                                    }
                                }
                                .disabled(viewModel.isLoading)
                            }
                            
                            HStack(spacing: 12) {
                                DebouncedPriceCard(
                                    title: "سعر الذهب (SAR)",
                                    value: $viewModel.goldPricePerGram,
                                    focusedField: $focusedField,
                                    field: .goldPrice
                                )
                                
                                DebouncedPriceCard(
                                    title: "سعر الفضة (SAR)",
                                    value: $viewModel.silverPricePerGram,
                                    focusedField: $focusedField,
                                    field: .silverPrice
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        if let lastUpdate = viewModel.lastUpdated {
                            Text("الأسعار عالمية - آخر تحديث: \(lastUpdate)")
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, -8)
                        }
                        
                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text(error)
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            if viewModel.goldPricePerGram == 0 {
                viewModel.fetchRates()
            }
        }
    }
    
    private var header: some View {
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
            
            Text("حاسبة الزكاة")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.gray)
            Text(title)
                .foregroundStyle(.gray)
        }
        .font(.caption.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Optimized Components

/// Equatable View to prevent re-renders of the gradient card
struct ZakatSummaryCardView: View, Equatable {
    let zakatDue: Double
    let isNisabReached: Bool
    let nisabThreshold: Double
    let currency: String
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "B45309"), Color(hex: "F59E0B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 16) {
                Text("إجمالي الزكاة المستحقة")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(zakatDue))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text(currency)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(.white)
                
                HStack {
                    Image(systemName: isNisabReached ? "checkmark.seal.fill" : "info.circle.fill")
                    Text(isNisabReached ? "بلغ النصاب الشرعي" : "لم يبلغ النصاب (> \(Int(nisabThreshold)))")
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
                .foregroundStyle(.white)
            }
            .padding(24)
        }
        .cornerRadius(24)
        .padding(.horizontal)
        .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

struct DebouncedInputRow: View {
    let title: String
    @Binding var value: Double
    var focusedField: FocusState<ZakatCalculatorView.Field?>.Binding
    var field: ZakatCalculatorView.Field
    let icon: String
    let color: Color
    
    @State private var text: String = ""
    @State private var updateTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            TextField("0", text: $text)
                .focused(focusedField, equals: field)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .frame(width: 120)
                .onChange(of: focusedField.wrappedValue) { _, newValue in
                    if newValue == field {
                        // Focus gained: ensure text matches value
                        if value == 0 && text.isEmpty { return } // Keep empty if 0
                        text = (value == 0) ? "" : String(format: "%.0f", value)
                    } else {
                        // Focus lost: commit immediately
                        commitValue()
                    }
                }
                .onChange(of: text) { _, newValue in
                    // Debounce update to prevent freeze
                    updateTask?.cancel()
                    updateTask = Task {
                        // Wait 300ms before updating the heavy view model
                        try? await Task.sleep(for: .seconds(0.3))
                        if !Task.isCancelled {
                            if let d = Double(newValue) {
                                value = d
                            } else if newValue.isEmpty {
                                value = 0
                            }
                        }
                    }
                }
                .onAppear {
                    if value != 0 {
                        text = String(format: "%.0f", value)
                    }
                }
        }
        .padding(16)
        .background(AppColors.onboardingSurface)
        .cornerRadius(16)
    }
    
    private func commitValue() {
        if let d = Double(text) {
            value = d
        } else {
            value = 0
        }
    }
}

struct DebouncedPriceCard: View {
    let title: String
    @Binding var value: Double
    var focusedField: FocusState<ZakatCalculatorView.Field?>.Binding
    var field: ZakatCalculatorView.Field
    
    @State private var text: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            
            HStack {
                TextField("Price", text: $text)
                    .focused(focusedField, equals: field)
                    .keyboardType(.decimalPad)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .onChange(of: focusedField.wrappedValue) { _, newValue in
                        if newValue == field {
                            text = String(format: "%.1f", value)
                        } else {
                            if let d = Double(text) { value = d }
                        }
                    }
                    .onChange(of: value) { _, newValue in
                        // Update text if value changes externally (e.g. API fetch)
                        // Make sure we don't overwrite user typing if focused
                        if focusedField.wrappedValue != field {
                            text = String(format: "%.1f", newValue)
                        }
                    }
                    .onChange(of: text) { _, newValue in
                        if let d = Double(newValue) {
                            value = d
                        }
                    }
                    .onAppear {
                         text = String(format: "%.1f", value)
                    }
                
                Text("ريال")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(12)
        .background(AppColors.onboardingSurface)
        .cornerRadius(16)
    }
}
