import SwiftUI

struct FavoritesView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: FavoritesViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                FavoritesContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }

    private func setupViewModel() {
        viewModel = FavoritesViewModel(
            favoritesRepository: container.makeFavoritesRepository(),
            dhikrRepository: container.makeDhikrRepository()
        )
    }
}

struct FavoritesContent: View {
    @Bindable var viewModel: FavoritesViewModel
    @State private var selectedDua: DhikrItem?

    var body: some View {
        ZStack {
            // Background
            AppColors.favoritesBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 20) {
                    HStack {
                        Text("المفضلة")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppColors.favoritesPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Segment control
                    segmentControl
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
                .background(AppColors.favoritesBg.opacity(0.95))

                // Content
                Group {
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewModel.isEmpty {
                        emptyState
                    } else {
                        favoritesList
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedSegment)
            }
        }
        .task {
            await viewModel.loadFavorites()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didClearData)) { _ in
            Task {
                await viewModel.loadFavorites()
            }
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua)
        }
    }

    // MARK: - Segment Control
    private var segmentControl: some View {
        HStack(spacing: 0) {
            SegmentButton(
                title: "الأذكار اليومية",
                isSelected: viewModel.selectedSegment == .daily
            ) {
                viewModel.selectSegment(.daily)
            }

            SegmentButton(
                title: "حصن المسلم",
                isSelected: viewModel.selectedSegment == .hisn
            ) {
                viewModel.selectSegment(.hisn)
            }
        }
        .padding(4)
        .background(AppColors.favoritesPrimary.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(AppColors.favoritesPrimary.opacity(0.05))
                    .frame(width: 220, height: 220)
                    .blur(radius: 20)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppColors.favoritesPrimary.opacity(0.2))
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.favoritesPrimary.opacity(0.1))
                            .offset(x: 40, y: -40)
                    )
            }

            VStack(spacing: 12) {
                Text("لم تضف أي ذكر بعد")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.favoritesPrimary)

                Text("الأذكار التي تفضلها ستظهر هنا للوصول السريع")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.favoritesPrimary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
            }

            Button {
                // Navigate to browse
            } label: {
                Text("اكتشف الأذكار")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(height: 50)
                    .padding(.horizontal, 40)
                    .background(AppColors.onboardingPrimary)
                    .clipShape(Capsule())
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
            }

            Spacer()
        }
    }

    // MARK: - Favorites List
    private var favoritesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredFavorites) { favorite in
                    FavoriteRow(
                        dhikr: favorite,
                        onTap: { selectedDua = favorite },
                        onRemove: {
                            try? viewModel.removeFavorite(favorite)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Segment Button
struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? AppColors.favoritesPrimary : AppColors.favoritesPrimary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? .white : .clear)
                        .shadow(color: isSelected ? Color.black.opacity(0.05) : Color.clear, radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Favorite Row
struct FavoriteRow: View {
    let dhikr: DhikrItem
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Content (Right in RTL -> leading in HStack)
                VStack(alignment: .leading, spacing: 4) {
                    Text(dhikr.title)
                        .font(.headline)
                        .foregroundStyle(AppColors.favoritesPrimary)
                        .multilineTextAlignment(.leading)

                    Text(dhikr.text)
                        .font(.caption)
                        .foregroundStyle(AppColors.favoritesPrimary.opacity(0.7))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Remove button (Left in RTL -> trailing in HStack)
                Button(action: onRemove) {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "heart.slash.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.onboardingSurface)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
