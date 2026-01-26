import SwiftUI

@MainActor
@Observable
final class ZakatViewModel {
    // Inputs (Gram weight or Value)
    var goldWeight: Double = 0
    var silverWeight: Double = 0
    var cashAmount: Double = 0
    var stocksAmount: Double = 0
    
    // Prices (Defaults, editable)
    var goldPricePerGram: Double = 250 // Example
    var silverPricePerGram: Double = 3.5 // Example
    
    // Logic
    var totalAssets: Double {
        (goldWeight * goldPricePerGram) +
        (silverWeight * silverPricePerGram) +
        cashAmount +
        stocksAmount
    }
    
    var nisabGold: Double { 85 * goldPricePerGram } // 85g gold standard
    var zakatDue: Double {
        totalAssets >= nisabGold ? totalAssets * 0.025 : 0
    }
    
    var isNisabReached: Bool {
        totalAssets >= nisabGold
    }
    
    func saveCalculation() {
        // Mock save for now
        print("Savings Zakat: \(zakatDue)")
    }
}

struct ZakatCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ZakatViewModel()
    @State private var showSaveAlert = false
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Color.clear.frame(width: 40, height: 40)
                    Spacer()
                    Text("حاسبة الزكاة")
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
                        // Summary Card (Gold Gradient)
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
                                
                                Text("\(Int(viewModel.zakatDue)) ريال")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(.white)
                                
                                HStack {
                                    Image(systemName: viewModel.isNisabReached ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    Text(viewModel.isNisabReached ? "بلغ النصاب الشرعي" : "لم يبلغ النصاب")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                            }
                            .padding(32)
                        }
                        .cornerRadius(24)
                        
                        // Inputs Section
                        VStack(spacing: 20) {
                            // Gold
                            InputRow(
                                title: "الذهب والفضة",
                                icon: "circle.grid.2x2.fill", // Generic fallback
                                color: .yellow
                            ) {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("وزن الذهب عيار 24")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                    }
                                    HStack {
                                        TextField("0", value: $viewModel.goldWeight, format: .number)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.leading)
                                            .foregroundStyle(.white)
                                        Text("جرام")
                                            .foregroundStyle(.gray)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Cash
                            InputRow(
                                title: "الأموال النقدية",
                                icon: "banknote.fill",
                                color: AppColors.success
                            ) {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("السيولة والحسابات البنكية")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                    }
                                    HStack {
                                        TextField("0", value: $viewModel.cashAmount, format: .number)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.leading)
                                            .foregroundStyle(.white)
                                        Text("ريال")
                                            .foregroundStyle(.gray)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Prices Update Section
                            VStack(alignment: .leading, spacing: 12) {
                                Label("أسعار اليوم (تقديرية)", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                
                                HStack(spacing: 12) {
                                    PriceCard(title: "ذهب", price: $viewModel.goldPricePerGram)
                                    PriceCard(title: "فضة", price: $viewModel.silverPricePerGram)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        // Save Button
                        Button {
                            viewModel.saveCalculation()
                            showSaveAlert = true
                        } label: {
                            Text("حفظ العملية")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(AppColors.onboardingPrimary)
                                .clipShape(Capsule())
                                .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.top, 16)
                    }
                    .padding(24)
                }
            }
        }
        .alert("تم الحفظ", isPresented: $showSaveAlert) {
            Button("موافق", role: .cancel) { }
        } message: {
            Text("تم حفظ عملية حساب الزكاة في السجل الخاص بك.")
        }
    }
}

// MARK: - Subviews for Zakat

struct InputRow<Content: View>: View {
    let title: String
    let icon: String // SF Symbol
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            
            content
        }
        .padding(20)
        .background(AppColors.onboardingSurface)
        .cornerRadius(20)
    }
}

struct PriceCard: View {
    let title: String
    @Binding var price: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            
            HStack {
                TextField("Price", value: $price, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                    .font(.subheadline.bold())
                Text("ريال")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity)
    }
}
