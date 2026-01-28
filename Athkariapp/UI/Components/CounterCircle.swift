import SwiftUI

/// Circular counter component for athkar sessions
struct CounterCircle: View {
    let currentCount: Int
    let targetCount: Int
    var size: CGFloat = 250 // Configurable size with default
    var activeColor: Color = AppColors.appPrimary // Configurable color
    var accentColor: Color = AppColors.onboardingPrimary
    let onTap: () -> Void


    private var progress: Double {
        guard targetCount > 0 else { return 0 }
        return min(Double(currentCount) / Double(targetCount), 1.0)
    }

    private var isCompleted: Bool {
        currentCount >= targetCount
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: size * 0.048
                    )

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(
                            lineWidth: 12,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                // Counter text
                VStack(spacing: size * 0.032) {
                    Text(currentCount.formatted(.number.locale(Locale(identifier: "en"))))
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: currentCount)

                    Text("من \(targetCount.formatted(.number.locale(Locale(identifier: "en"))))")
                        .font(.system(size: size * 0.072))
                        .foregroundStyle(.secondary)
                }

                // Completion checkmark
                if isCompleted {
                    VStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: size * 0.1))
                            .foregroundStyle(AppColors.onboardingPrimary)
                            .padding(.bottom, size * 0.08)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .accessibilityLabel("عداد التسبيح")
        .accessibilityValue("\(currentCount) من \(targetCount)")
        .accessibilityHint("اضغط للعد")
    }
}

#Preview {
    VStack(spacing: 40) {
        CounterCircle(currentCount: 0, targetCount: 33) { }
        CounterCircle(currentCount: 15, targetCount: 33) { }
        CounterCircle(currentCount: 33, targetCount: 33) { }
    }
    .padding()
}
