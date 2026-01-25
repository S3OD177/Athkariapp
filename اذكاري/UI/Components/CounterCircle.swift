import SwiftUI

/// Circular counter component for athkar sessions
struct CounterCircle: View {
    let currentCount: Int
    let targetCount: Int
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
                        lineWidth: 12
                    )

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isCompleted ? Color.green : Color.appPrimary,
                        style: StrokeStyle(
                            lineWidth: 12,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                // Counter text
                VStack(spacing: 8) {
                    Text(currentCount.arabicNumeral)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: currentCount)

                    Text("من \(targetCount.arabicNumeral)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Completion checkmark
                if isCompleted {
                    VStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 250, height: 250)
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
