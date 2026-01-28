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
    @State private var selectedCategory: HisnCategory?
    @State private var showAllDuas = false
    @Environment(\.appContainer) private var container

    // Grid Columns
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Premium Header
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Search Bar
                        searchBar
                            .padding(.horizontal, 20)
                        
                        // Categories Grid
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("التصنيفات")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(HisnCategory.allCases, id: \.self) { category in
                                    CategoryDetailsCard(category: category) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationDestination(item: $selectedCategory) { category in
            CategoryDetailView(
                category: category,
                repository: container.makeDhikrRepository()
            )
        }
    }

    // MARK: - Premium Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("المكتبة")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("حصن المسلم من أذكار الكتاب والسنة")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textGray)
            }
            Spacer()
            
            Image(systemName: "books.vertical.fill")
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

            TextField("", text: $viewModel.searchQuery, prompt: Text("بحث في الأذكار...").foregroundStyle(AppColors.textGray.opacity(0.7)))
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
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.onboardingSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.onboardingBorder, lineWidth: 1)
        )
    }
}

struct CategoryDetailsCard: View {
    let category: HisnCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppColors.onboardingPrimary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(AppColors.onboardingPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.textGray.opacity(0.5))
                }
                
                Text(category.arabicName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text("تصفح الأذكار")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textGray)
            }
            .padding(16)
            .background(AppColors.onboardingSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - CategoryDetailView

struct CategoryDetailView: View {
    let category: HisnCategory
    let repository: DhikrRepositoryProtocol
    
    @State private var duas: [DhikrItem] = []
    @State private var selectedDua: DhikrItem?
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Mostly handled by NavigationBar in this context, but we can customize)
                
                if duas.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(duas) { dua in
                                DuaListRow(dua: dua) {
                                    selectedDua = dua
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle(category.arabicName) // Use standard title for simplicity in detail view
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.homeBackground, for: .navigationBar)
        .task {
            // Load data - Running on MainActor (View context), calling MainActor repository.
            // No detached task needed, solving Sendable issues.
            do {
                duas = try repository.fetchByHisnCategory(category)
            } catch {
                print("Error loading category items: \(error)")
            }
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua)
        }
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

