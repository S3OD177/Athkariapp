import SwiftUI

struct DuaDetailView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    let dua: DhikrItem
    var fontSize: Double = 1.0

    @State private var isFavorite = false
    @State private var showAddToRoutineSheet = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Bismillah
                    Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                        .font(.system(size: 18 * fontSize))
                        .foregroundStyle(AppColors.onboardingPrimary)
                        .padding(.top, 24)

                    // Dua text
                    Text(dua.text)
                        .font(.system(size: 26 * fontSize, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineSpacing(14 * fontSize)
                        .padding(.horizontal, 20)

                    // Reference and repeat count
                    HStack {
                        // Repeat count (Right in RTL -> leading)
                        HStack(spacing: 4) {
                            Text("\(dua.repeatCount)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)

                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }

                        Spacer()

                        // Reference (Left in RTL -> trailing)
                        if let reference = dua.reference {
                            Text(reference)
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider()
                        .background(AppColors.separator)
                        .padding(.horizontal, 20)

                    // Action buttons
                    HStack(spacing: 20) {
                        // Favorite
                        DetailActionButton(
                            title: "المفضلة",
                            icon: isFavorite ? "star.fill" : "star",
                            isActive: isFavorite
                        ) {
                            toggleFavorite()
                        }

                        // Add to routine
                        DetailActionButton(
                            title: "أضف للروتين",
                            icon: "plus.circle",
                            isActive: false
                        ) {
                            showAddToRoutineSheet = true
                        }

                        // Share
                        DetailActionButton(
                            title: "مشاركة",
                            icon: "square.and.arrow.up",
                            isActive: false
                        ) {
                            showShareSheet = true
                        }
                    }
                    .padding(.horizontal, 20)

                    // Translation toggle (placeholder)
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.gray)

                        Text("إظهار المعنى والتفسير")
                            .font(.subheadline)
                            .foregroundStyle(.gray)

                        Spacer()

                        Text("الترجمة")
                            .font(.subheadline)
                            .foregroundStyle(.white)

                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.onboardingSurface)
                    )
                    .padding(.horizontal, 20)

                    // Benefit if available
                    if let benefit = dua.benefit {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("فضل الذكر")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(benefit)
                                .font(.system(size: 15 * fontSize))
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.onboardingSurface)
                        )
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.homeBackground)
            .navigationTitle(dua.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.right") // Points right for Arabic back
                            .foregroundStyle(.gray)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // More options
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .task {
                checkFavoriteStatus()
            }
            .sheet(isPresented: $showAddToRoutineSheet) {
                AddToRoutineSheet(dua: dua)
                    .presentationDetents([.medium])
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

    private func checkFavoriteStatus() {
        let repo = container.makeFavoritesRepository()
        isFavorite = (try? repo.isFavorite(dhikrId: dua.id)) ?? false
    }

    private func toggleFavorite() {
        let repo = container.makeFavoritesRepository()
        if let result = try? repo.toggleFavorite(dhikrId: dua.id) {
            isFavorite = result
        }
    }
}

// MARK: - Detail Action Button
struct DetailActionButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isActive ? AppColors.onboardingPrimary : .white)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.onboardingSurface)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add to Routine Sheet
struct AddToRoutineSheet: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    let dua: DhikrItem

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach([SlotKey.morning, .evening, .afterFajr, .sleep], id: \.self) { slot in
                        Button {
                            addToRoutine(slot)
                        } label: {
                            HStack {
                                Spacer()
                                Text(slot.arabicName)
                                    .foregroundStyle(.white)
                                Image(systemName: slot.icon)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                } header: {
                    Text("اختر الوقت")
                        .foregroundStyle(.gray)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("إضافة للروتين")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إلغاء") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addToRoutine(_ slot: SlotKey) {
        let repo = container.makeUserRoutineLinkRepository()
        try? repo.addLink(dhikrId: dua.id, slotKey: slot)
        dismiss()
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

#Preview {
    DuaDetailView(dua: DhikrItem(
        source: .hisn,
        title: "آية الكرسي",
        category: "hisn",
        hisnCategory: .protection,
        text: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ",
        reference: "سورة البقرة - آية 255",
        repeatCount: 1,
        benefit: "من قرأها في ليلة لم يزل عليه من الله حافظ"
    ), fontSize: 1.2)
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
