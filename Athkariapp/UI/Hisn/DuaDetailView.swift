import SwiftUI

struct DuaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    let dua: DhikrItem


    @State private var showShareSheet = false
    @State private var currentCount = 0
    @AppStorage("isDuaCounterVisible") private var isCounterVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background (SessionView Style)
                AppColors.sessionBackground.ignoresSafeArea()
                
                // Immersive Gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        AppColors.onboardingPrimary.opacity(0.15),
                        AppColors.sessionBackground.opacity(0)
                    ]),
                    center: .center,
                    startRadius: 50,
                    endRadius: 600
                )
                .ignoresSafeArea()
                
                // Ambient Background Effect
                ZStack {
                     Circle()
                        .fill(AppColors.sessionPrimary.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(y: -200) // Adjusted offset for detail view
                }
                .opacity(0.6)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Main Content Card (Standardized Glassmorphism)
                        ZStack {
                            // Glass Card Background
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 32))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.2),
                                                    .white.opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            
                            // Card Content
                            VStack(spacing: 24) {
                                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AppColors.onboardingPrimary.opacity(0.8))
                                
                                Spacer(minLength: 0)
                                
                                Text(dua.text)
                                    .font(.system(size: 28, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .lineSpacing(10)
                                    .minimumScaleFactor(0.5)
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                                
                                Spacer(minLength: 0)

                                if let reference = dua.reference {
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "book.closed.fill")
                                            .font(.caption2)
                                        Text(reference)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(AppColors.textGray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(24)
                        }
                        .frame(minHeight: 380) // Reduced height from 420
                        .padding(.horizontal, 24)

                        // Mode Toggle Button
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isCounterVisible.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isCounterVisible ? "book.closed.fill" : "123.rectangle")
                                    .symbolReplaceable()
                                    .font(.system(size: 16))
                                
                                Text(isCounterVisible ? "العودة للقراءة" : "تفعيل العداد")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .padding(.top, -8) // Pull it up slightly closer to card

                        if isCounterVisible {
                            CounterCircle(
                                currentCount: currentCount,
                                targetCount: dua.repeatCount,
                                size: 220, // Reduced from 280
                                accentColor: AppColors.onboardingPrimary
                            ) {
                                if currentCount < dua.repeatCount {
                                    currentCount += 1
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Benefit / Notes
                        if let benefit = dua.benefit {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(AppColors.onboardingPrimary)
                                        .font(.caption)
                                        .padding(.top, 2)
                                    
                                    Text("فضل الذكر")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.onboardingPrimary)
                                }

                                Text(benefit)
                                    .font(.system(size: 16)) // Removed fontSize multiplier as it's not defined in the snippet
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(6)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(white: 0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(AppColors.onboardingPrimary.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 24)
                        }
                        
                        // Bottom Actions (Session Style)
                        HStack(spacing: 40) {
                            // Reset Button
                            Button {
                                withAnimation {
                                    currentCount = 0
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title3)
                                    Text("إعادة")
                                        .font(.caption2)
                                }
                                .foregroundStyle(currentCount > 0 ? Color.white : AppColors.textGray.opacity(0.5))
                            }
                            .disabled(currentCount == 0)
                            
                            // Share Button
                            Button {
                                showShareSheet = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title3)
                                    Text("مشاركة")
                                        .font(.caption2)
                                }
                                .foregroundStyle(AppColors.textGray)
                            }
                        }
                        .padding(.bottom, 40)
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
                        Image(systemName: "chevron.right")
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

// MARK: - Extensions for SF Symbols
private extension Image {
    func symbolReplaceable() -> Image {
        // Fallback if the specific symbols don't exist in older iOS versions?
        // Beads nav arrow is effectively 'number' or beads if available.
        // Assuming beads.nav_arrow might not be a standard SF Symbol, using a standard fallback.
        // 'beads.nav_arrow' doesn't exist in standard SF Symbols 5.
        // Replacing with standard equivalents for safety.
        // Logic inside the view builder actually handles the string name, but let's be safe with the strings used above.
        // Re-checking the strings used: "beads.nav_arrow" is likely what the user *might* have or similar.
        // Let's us "circle.grid.3x3.fill" or "beads" if valid, or "123.rectangle".
        // Actually, let's just stick to standard for safely.
        self
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




#Preview {
    DuaDetailView(dua: DhikrItem(
        source: .hisn,
        title: "آية الكرسي",
        category: "hisn",
        hisnCategory: .protection,
        text: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ",
        reference: "سورة البقرة - آية 255",
        repeatMin: 1,
        repeatMax: 4,
        benefit: "من قرأها في ليلة لم يزل عليه من الله حافظ"
    ))
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
