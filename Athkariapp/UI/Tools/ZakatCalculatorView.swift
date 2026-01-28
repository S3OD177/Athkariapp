import SwiftUI

// MARK: - API Models

private struct ZakatApiResponse: Codable {
    let status: String
    let updated_at: String
    let data: ZakatApiData
}

private struct ZakatApiData: Codable {
    let nisab_thresholds: NisabThresholds
}

private struct NisabThresholds: Codable {
    let gold: MetalInfo
    let silver: MetalInfo
}

private struct MetalInfo: Codable {
    let unit_price: Double
}

// MARK: - Service

actor ZakatService {
    static let shared = ZakatService()

    private let endpoint = "https://islamicapi.com/api/v1/zakat-nisab/?standard=common&currency=sar&unit=g&api_key=aZUHsql6tGOVHu1YrjvxyU49ASjdrnoC7rr5p0NawQgjxJNP"

    struct Rates {
        let goldPrice: Double
        let silverPrice: Double
        let lastUpdated: String
    }

    func fetchRates() async throws -> Rates {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ZakatApiResponse.self, from: data)

        return Rates(
            goldPrice: decoded.data.nisab_thresholds.gold.unit_price,
            silverPrice: decoded.data.nisab_thresholds.silver.unit_price,
            lastUpdated: decoded.updated_at
        )
    }
}

// MARK: - ViewModel

@MainActor
final class ZakatViewModel: ObservableObject {
    // MARK: Inputs
    @Published var goldGrams: String = ""
    @Published var silverGrams: String = ""
    @Published var cash: String = ""
    @Published var investments: String = ""
    @Published var goldPrice: String = "380"
    @Published var silverPrice: String = "4.5"

    // MARK: State
    @Published var isLoading = false
    @Published var lastUpdated: String?
    @Published var showError = false

    // MARK: Computed
    var goldValue: Double { (Double(goldGrams) ?? 0) * (Double(goldPrice) ?? 0) }
    var silverValue: Double { (Double(silverGrams) ?? 0) * (Double(silverPrice) ?? 0) }
    var cashValue: Double { Double(cash) ?? 0 }
    var investmentValue: Double { Double(investments) ?? 0 }

    var totalWealth: Double {
        goldValue + silverValue + cashValue + investmentValue
    }

    var nisabThreshold: Double {
        85.0 * (Double(goldPrice) ?? 1)
    }

    var isAboveNisab: Bool {
        totalWealth >= nisabThreshold
    }

    var zakatAmount: Double {
        isAboveNisab ? totalWealth * 0.025 : 0
    }

    // MARK: Actions
    func loadPrices() {
        guard !isLoading else { return }
        isLoading = true
        showError = false

        Task {
            do {
                let rates = try await ZakatService.shared.fetchRates()
                goldPrice = String(format: "%.1f", rates.goldPrice)
                silverPrice = String(format: "%.1f", rates.silverPrice)
                lastUpdated = formatDate(rates.lastUpdated)
            } catch {
                showError = true
            }
            isLoading = false
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "ar")
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return iso
    }

    func reset() {
        goldGrams = ""
        silverGrams = ""
        cash = ""
        investments = ""
    }
}

// MARK: - Main View

struct ZakatCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ZakatViewModel()
    @FocusState private var focused: Field?

    enum Field: Hashable {
        case gold, silver, cash, investments, goldPrice, silverPrice
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        resultCard
                        assetsSection
                        pricesSection
                        infoSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            vm.loadPrices()
        }
        .alert("فشل تحميل الأسعار", isPresented: $vm.showError) {
            Button("إعادة المحاولة") { vm.loadPrices() }
            Button("إلغاء", role: .cancel) { }
        } message: {
            Text("تأكد من اتصالك بالإنترنت")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: Circle())
            }

            Spacer()

            Text("حاسبة الزكاة")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button { vm.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Result Card

    private var resultCard: some View {
        VStack(spacing: 16) {
            // Zakat Amount
            VStack(spacing: 4) {
                Text("الزكاة المستحقة")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatNumber(vm.zakatAmount))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("ريال")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Nisab Status
            HStack(spacing: 8) {
                Image(systemName: vm.isAboveNisab ? "checkmark.circle.fill" : "info.circle.fill")
                    .foregroundStyle(vm.isAboveNisab ? .green : .orange)

                Text(vm.isAboveNisab ? "بلغ النصاب" : "لم يبلغ النصاب")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.15), in: Capsule())

            // Totals
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("إجمالي الأصول")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(formatNumber(vm.totalWealth)) ر.س")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 30)

                VStack(spacing: 2) {
                    Text("حد النصاب")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(formatNumber(vm.nisabThreshold)) ر.س")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "c9880b"), Color(hex: "daa520")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color(hex: "daa520").opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Assets Section

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("الأصول", icon: "briefcase.fill")

            VStack(spacing: 10) {
                AssetRow(
                    icon: "seal.fill",
                    iconColor: .yellow,
                    title: "الذهب",
                    subtitle: "بالجرام",
                    value: $vm.goldGrams,
                    focused: $focused,
                    field: .gold
                )

                AssetRow(
                    icon: "circle.fill",
                    iconColor: Color(hex: "C0C0C0"),
                    title: "الفضة",
                    subtitle: "بالجرام",
                    value: $vm.silverGrams,
                    focused: $focused,
                    field: .silver
                )

                AssetRow(
                    icon: "banknote.fill",
                    iconColor: .green,
                    title: "النقد",
                    subtitle: "ريال سعودي",
                    value: $vm.cash,
                    focused: $focused,
                    field: .cash
                )

                AssetRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .blue,
                    title: "الاستثمارات",
                    subtitle: "أسهم وصناديق",
                    value: $vm.investments,
                    focused: $focused,
                    field: .investments
                )
            }
        }
    }

    // MARK: - Prices Section

    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("أسعار السوق", icon: "chart.bar.fill")

                Spacer()

                Button {
                    vm.loadPrices()
                } label: {
                    HStack(spacing: 4) {
                        if vm.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text("تحديث")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "daa520"))
                }
                .disabled(vm.isLoading)
            }

            HStack(spacing: 12) {
                PriceCard(
                    title: "سعر الذهب",
                    value: $vm.goldPrice,
                    focused: $focused,
                    field: .goldPrice
                )

                PriceCard(
                    title: "سعر الفضة",
                    value: $vm.silverPrice,
                    focused: $focused,
                    field: .silverPrice
                )
            }

            if let date = vm.lastUpdated {
                Text("آخر تحديث: \(date)")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("معلومات", icon: "info.circle.fill")

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(text: "نسبة الزكاة: 2.5% من إجمالي الأصول")
                InfoRow(text: "النصاب: ما يعادل 85 جرام من الذهب")
                InfoRow(text: "الأسعار تقريبية وقد تختلف عن السوق المحلي")
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en")
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Asset Row

private struct AssetRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var value: String
    var focused: FocusState<ZakatCalculatorView.Field?>.Binding
    let field: ZakatCalculatorView.Field

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }

            Spacer()

            // Input
            TextField("0", text: $value)
                .focused(focused, equals: field)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 100)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Price Card

private struct PriceCard: View {
    let title: String
    @Binding var value: String
    var focused: FocusState<ZakatCalculatorView.Field?>.Binding
    let field: ZakatCalculatorView.Field

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.gray)

            HStack(spacing: 6) {
                TextField("0", text: $value)
                    .focused(focused, equals: field)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text("ر.س/جرام")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "daa520"))
                .frame(width: 5, height: 5)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Preview

#Preview {
    ZakatCalculatorView()
}
