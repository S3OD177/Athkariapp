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
                // Premium Header
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Search & Categories & List
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Search
                        searchBar
                            .padding(.horizontal, 20)

                        // Usage of a real "Library" feel requires categories to be prominent
                        categorySection

                        // Dua List
                        if viewModel.filteredDuaList.isEmpty {
                            emptyState
                                .frame(height: 300)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.filteredDuaList) { dua in
                                    DuaListRow(dua: dua) {
                                        selectedDua = dua
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .task {
            await viewModel.loadDuas()
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua)
        }
    }

    // MARK: - Premium Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("أذكاري")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("الأذكار والدعوات من الكتاب والسنة")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textGray)
            }
            Spacer()
            
            // Decorative Icon/Logo
            Image(systemName: "book.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.onboardingPrimary)
                .padding(12)
                .background(
                    Circle()
                        .fill(AppColors.onboardingSurface)
                )
                .overlay(
                    Circle()
                        .stroke(AppColors.onboardingBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textGray)
                .font(.system(size: 18, weight: .medium))

            TextField("", text: $viewModel.searchQuery, prompt: Text("بحث...").foregroundStyle(AppColors.textGray.opacity(0.7)))
                .foregroundStyle(.white)
                .tint(AppColors.onboardingPrimary)
                .font(.system(size: 16))

            if !viewModel.searchQuery.isEmpty {
                Button {
                    withAnimation {
                        viewModel.searchQuery = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textGray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16) // Taller improved touch area
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.onboardingSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.onboardingBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    // MARK: - Category Section
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("التصنيفات")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // "All" Category
                    CategoryIcon(
                        title: "الكل",
                        icon: "square.grid.2x2",
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        withAnimation(.snappy) {
                            viewModel.selectCategory(nil)
                        }
                    }

                    ForEach(HisnCategory.allCases, id: \.self) { category in
                        CategoryIcon(
                            title: category.arabicName,
                            icon: category.icon,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            withAnimation(.snappy) {
                                viewModel.selectCategory(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textGray.opacity(0.5))
            
            Text("لا توجد نتائج")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColors.textGray)
            
            Spacer()
        }
    }
}

// MARK: - Category Icon (Vertical)
struct CategoryIcon: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.onboardingPrimary : AppColors.onboardingSurface)
                        .frame(width: 60, height: 60)
                        
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? .white : AppColors.textGray)
                }
                .overlay(
                    Circle()
                        .stroke(AppColors.onboardingBorder, lineWidth: isSelected ? 0 : 1)
                )
                .shadow(color: isSelected ? AppColors.onboardingPrimary.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)

                // Title
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : AppColors.textGray)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(width: 70) // Fixed width for alignment
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Dua List Row (Card)
struct DuaListRow: View {
    let dua: DhikrItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Accent Bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.onboardingPrimary)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 4)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(dua.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(dua.text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.textGray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textGray.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.onboardingSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.onboardingBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
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
    var scaleAmount: CGFloat = 0.97
    var duration: Double = 0.1
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.easeInOut(duration: duration), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}
