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
        VStack(spacing: 0) {
            // Title
            Text("المفضلة")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Segment control
            segmentControl
                .padding(.horizontal, 16)
                .padding(.top, 20)

            // Content
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
        .background(Color.black)
        .task {
            await viewModel.loadFavorites()
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            // Illustration placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.85, green: 0.8, blue: 0.7))
                .frame(width: 180, height: 180)
                .overlay {
                    Image(systemName: "lantern.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.brown.opacity(0.6))
                }

            Text("لم تضف أي ذكر بعد")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("اضغط على أيقونة القلب ♥ بجانب الأذكار لإضافتها إلى قائمتك المفضلة والوصول إليها بسرعة.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                // Navigate to browse
            } label: {
                Text("تصفح الأذكار")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
    }

    // MARK: - Favorites List
    private var favoritesList: some View {
        ScrollView {
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
            .padding(.horizontal, 16)
            .padding(.top, 20)
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
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue : Color.clear)
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
                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }

                Spacer()

                // Content
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dhikr.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)

                    Text(dhikr.text)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.1))
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
