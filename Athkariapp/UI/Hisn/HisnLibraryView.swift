import SwiftUI

struct HisnLibraryView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: HisnViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                HisnLibraryContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }

    private func setupViewModel() {
        viewModel = HisnViewModel(
            dhikrRepository: container.makeDhikrRepository(),
            favoritesRepository: container.makeFavoritesRepository(),
            settingsRepository: container.makeSettingsRepository()
        )
    }
}

struct HisnLibraryContent: View {
    @Bindable var viewModel: HisnViewModel
    @State private var selectedDua: DhikrItem?

    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("حصن المسلم")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Search bar
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                // Category chips
                categoryChips
                    .padding(.top, 16)

                // Dua list
                if viewModel.filteredDuaList.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredDuaList) { dua in
                                DuaListRow(dua: dua, fontSize: viewModel.fontSize) {
                                    selectedDua = dua
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .task {
            await viewModel.loadDuas()
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua, fontSize: viewModel.fontSize)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray.opacity(0.8))

            TextField("", text: $viewModel.searchQuery, prompt: Text("بحث عن ذكر أو دعاء...").foregroundStyle(.gray.opacity(0.8)))
                .foregroundStyle(.white)
                .tint(AppColors.onboardingPrimary)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.onboardingSurface)
        )
    }

    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All categories chip
                CategoryChip(
                    title: "الكل",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectCategory(nil)
                }

                ForEach([HisnCategory.waking, .sleeping, .prayer, .travel], id: \.self) { category in
                    CategoryChip(
                        title: category.arabicName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectCategory(category)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.4))
            
            Text("لا توجد نتائج")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.gray)
            
            if !viewModel.searchQuery.isEmpty {
                Text("جرب البحث بكلمات مختلفة")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray.opacity(0.8))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.onboardingPrimary : AppColors.onboardingSurface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? AppColors.onboardingPrimary : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - DuaListRow
struct DuaListRow: View {
    let dua: DhikrItem
    let fontSize: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Content Stack
                VStack(alignment: .leading, spacing: 6) {
                    Text(dua.title)
                        .font(.system(size: 17 * fontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true) // Prevents truncation inappropriately

                    Text(dua.text)
                        .font(.system(size: 14 * fontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2) // Allow 2 lines for better context
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                // Use chevron.backward for RTL "Back" semantic, but here we want "Detail" indicator.
                // In iOS RTL, standard disclosure indicator points LEFT (<).
                // chevron.left points Left.
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold)) // Slightly lighter weight
                    .foregroundStyle(AppColors.onboardingPrimary.opacity(0.8)) // Tinted
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.onboardingSurface)
            )
            .contentShape(Rectangle()) // Improves tap area
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    NavigationStack {
        HisnLibraryView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var duration: Double = 0.1
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.easeInOut(duration: duration), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}
