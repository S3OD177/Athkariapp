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
            favoritesRepository: container.makeFavoritesRepository()
        )
    }
}

struct HisnLibraryContent: View {
    @Bindable var viewModel: HisnViewModel
    @State private var selectedDua: DhikrItem?

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("حصن المسلم")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Search bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // Category chips
            categoryChips
                .padding(.top, 16)

            // Dua list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredDuaList) { dua in
                        DuaListRow(dua: dua) {
                            selectedDua = dua
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color.black)
        .task {
            await viewModel.loadDuas()
        }
        .sheet(item: $selectedDua) { dua in
            DuaDetailView(dua: dua)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)

            TextField("", text: $viewModel.searchQuery, prompt: Text("بحث عن ذكر أو دعاء...").foregroundStyle(.gray))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)

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
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
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

                ForEach([HisnCategory.sleeping, .prayer, .travel], id: \.self) { category in
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
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(white: 0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dua List Row
struct DuaListRow: View {
    let dua: DhikrItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .trailing, spacing: 8) {
                Text(dua.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)

                Text(dua.text)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
        HisnLibraryView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
