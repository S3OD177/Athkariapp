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

// MARK: - Main Library View
struct HisnLibraryContent: View {
    @Bindable var viewModel: HisnViewModel
    @State private var selectedChapter: DhikrItem?
    @State private var selectedDua: DhikrItem?
    @State private var navigationPath = NavigationPath()
    @State private var chapterItemsCache: [String: [DhikrItem]] = [:]
    @Environment(\.appContainer) private var container

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColors.homeBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Premium Header
                    headerView
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(AppColors.onboardingPrimary)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 24) {
                                searchBar
                                    .padding(.horizontal, 20)

                                if viewModel.filteredChapters.isEmpty {
                                    emptyState
                                        .padding(.top, 40)
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(viewModel.filteredChapters) { chapter in
                                            Button {
                                                openChapter(chapter)
                                            } label: {
                                                ChapterRow(chapter: chapter)
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedChapter) { chapter in
            ChapterDetailView(
                chapterTitle: chapter.title,
                repository: container.makeDhikrRepository()
            )
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua)
        }
        .task {
            // Load chapters on appear
            if viewModel.chapters.isEmpty {
                await viewModel.loadData()
            }
        }
    }

    private func openChapter(_ chapter: DhikrItem) {
        Task {
            do {
                let items: [DhikrItem]
                if let cachedItems = chapterItemsCache[chapter.title] {
                    items = cachedItems
                } else {
                    items = try container.makeDhikrRepository().fetchByTitle(chapter.title)
                    chapterItemsCache[chapter.title] = items
                }

                if items.count == 1, let first = items.first {
                    selectedDua = first
                } else {
                    selectedChapter = chapter
                }
            } catch {
                selectedChapter = chapter
            }
        }
    }

    // MARK: - Premium Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("حصن المسلم")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("قائمة الأذكار والأدعية")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textGray)
            }
            Spacer()
            
            Image(systemName: "book.pages.fill")
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

            TextField("", text: $viewModel.searchQuery, prompt: Text("ابحث عن ذكر...").foregroundStyle(AppColors.textGray.opacity(0.7)))
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.searchQuery.isEmpty ? "book.closed" : "magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppColors.onboardingPrimary)
                .frame(width: 72, height: 72)
                .background(AppColors.onboardingSurface)
                .clipShape(Circle())

            Text(viewModel.searchQuery.isEmpty ? "لا توجد أذكار حالياً" : "لا توجد نتائج")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text(viewModel.searchQuery.isEmpty ? "ستظهر قائمة الأذكار بعد تحميل البيانات." : "جرّب كلمة أخرى أو امسح البحث.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textGray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    withAnimation {
                        viewModel.searchQuery = ""
                    }
                } label: {
                    Text("مسح البحث")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Chapter Row Component
struct ChapterRow: View {
    let chapter: DhikrItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkmark / Icon
            ZStack {
                Circle()
                    .fill(AppColors.onboardingPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.onboardingPrimary)
            }
            
            Text(chapter.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.textGray.opacity(0.4))
        }
        .padding(16)
        .background(AppColors.onboardingSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Chapter Detail View
struct ChapterDetailView: View {
    let chapterTitle: String
    let repository: DhikrRepositoryProtocol
    
    @State private var duas: [DhikrItem] = []
    @State private var selectedDua: DhikrItem?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(AppColors.onboardingPrimary)
                        Spacer()
                    }
                } else if duas.isEmpty {
                    ContentUnavailableView {
                        Label("لا توجد أذكار", systemImage: "book.closed")
                    } description: {
                        Text("لم يتم العثور على عناصر في هذا الباب.")
                    }
                    .foregroundStyle(.white)
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
        .navigationTitle("الأذكار")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.homeBackground, for: .navigationBar)
        .task {
            do {
                duas = try repository.fetchByTitle(chapterTitle)
            } catch {
                print("Error loading chapter items: \(error)")
            }
            isLoading = false
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua)
        }
    }
}

// MARK: - Dua List Row (Reused)
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
                    // Only show title if it's different context, otherwise just show text preview
                    // For Hisn, title is often the Chapter Name, which we already know.
                    // But duplicates have same title.
                    // Let's show filtered text.
                    
                    Text(dua.text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
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
