import SwiftUI

struct DuaDetailView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    let dua: DhikrItem
    var fontSize: Double = 1.0

    @State private var showShareSheet = false
    @State private var currentCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.homeBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header Section
                        VStack(spacing: 16) {
                            Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                .font(.system(size: 16 * fontSize, weight: .medium))
                                .foregroundStyle(AppColors.onboardingPrimary.opacity(0.8))
                                .padding(.top, 16)

                            // Dua text
                            Text(dua.text)
                                .font(.system(size: 24 * fontSize, weight: .semibold)) // Slightly bolder
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .lineSpacing(12 * fontSize)
                                .padding(.horizontal, 24)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Counter Section
                        VStack(spacing: 24) {
                            CounterCircle(
                                currentCount: currentCount,
                                targetCount: dua.repeatCount,
                                size: 220
                            ) {
                                if currentCount < dua.repeatCount {
                                    currentCount += 1
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            }
                            
                            // Reset / Undo (Optional utility)
                            if currentCount > 0 {
                                Button {
                                    withAnimation {
                                        currentCount = 0
                                    }
                                } label: {
                                    Label("إعادة العد", systemImage: "arrow.counterclockwise")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }

                        // Reference
                        if let reference = dua.reference {
                            Text(reference)
                                .font(.system(size: 14))
                                .foregroundStyle(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 24)

                        // Action buttons
                        HStack(spacing: 16) {
                            // Share
                            DetailActionButton(
                                title: "مشاركة",
                                icon: "square.and.arrow.up",
                                isActive: false
                            ) {
                                showShareSheet = true
                            }
                        }
                        .padding(.horizontal, 24)

                        // Benefit if available
                        if let benefit = dua.benefit {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("فضل الذكر", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.onboardingPrimary)

                                Text(benefit)
                                    .font(.system(size: 16 * fontSize))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(6)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(white: 0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.onboardingPrimary.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 24)
                        }

                        Spacer()
                            .frame(height: 100)
                    }
                }
            }
            .navigationTitle(dua.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.right") // Points right for Arabic back
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }

    private var shareText: String {
        var text = dua.text
        if let reference = dua.reference {
            text += "\n\n\(reference)"
        }
        text += "\n\nمن تطبيق اذكاري"
        return text
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Helper Views
struct DetailActionButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? AppColors.onboardingPrimary : .white)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                 RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? AppColors.onboardingPrimary.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}



#Preview {
    DuaDetailView(dua: DhikrItem(
        source: .hisn,
        title: "آية الكرسي",
        category: "hisn",
        hisnCategory: .protection,
        text: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ",
        reference: "سورة البقرة - آية 255",
        repeatMin: 1,
        benefit: "من قرأها في ليلة لم يزل عليه من الله حافظ"
    ), fontSize: 1.2)
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
