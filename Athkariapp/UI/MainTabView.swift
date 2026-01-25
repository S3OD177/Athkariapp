import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "home"
    case hisn = "hisn"
    case favorites = "favorites"
    case settings = "settings"

    var title: String {
        switch self {
        case .home: return "الرئيسية"
        case .hisn: return "المكتبة"
        case .favorites: return "المفضلة"
        case .settings: return "الإعدادات"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .hisn: return "book.fill"
        case .favorites: return "heart.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                HomeView(navigationPath: $navigationPath)
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.icon)
            }
            .tag(AppTab.home)

            NavigationStack {
                HisnLibraryView()
            }
            .tabItem {
                Label(AppTab.hisn.title, systemImage: AppTab.hisn.icon)
            }
            .tag(AppTab.hisn)

            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label(AppTab.favorites.title, systemImage: AppTab.favorites.icon)
            }
            .tag(AppTab.favorites)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
            .tag(AppTab.settings)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
