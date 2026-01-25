import SwiftUI

struct SettingsView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                SettingsContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }

    private func setupViewModel() {
        viewModel = SettingsViewModel(
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService,
            hapticsService: container.hapticsService
        )
    }
}

struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("الإعدادات")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 8)

                // Appearance section
                appearanceSection

                // Preferences section
                preferencesSection

                // Prayer times section
                prayerTimesSection

                // App info
                appInfoSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color.black)
        .task {
            await viewModel.loadSettings()
        }
    }

    // MARK: - Appearance Section
    private var appearanceSection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Text("المظهر والعرض")
                .font(.subheadline)
                .foregroundStyle(.gray)

            // Theme picker
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ThemeButton(
                        title: "داكن",
                        isSelected: viewModel.theme == .dark
                    ) {
                        viewModel.updateTheme(.dark)
                    }

                    ThemeButton(
                        title: "فاتح",
                        isSelected: viewModel.theme == .light
                    ) {
                        viewModel.updateTheme(.light)
                    }

                    ThemeButton(
                        title: "تلقائي",
                        isSelected: viewModel.theme == .system
                    ) {
                        viewModel.updateTheme(.system)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.1))
                )

                // Font preview
                VStack(alignment: .trailing, spacing: 8) {
                    Text("الخط")
                        .font(.subheadline)
                        .foregroundStyle(.gray)

                    VStack(spacing: 8) {
                        Text("سبحان الله وبحمده")
                            .font(.title2)
                            .foregroundStyle(.white)

                        Text("سبحان الله العظيم")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.15))
                    )

                    // Font size slider (respects system Dynamic Type)
                    HStack {
                        Text("أ")
                            .font(.caption)
                            .foregroundStyle(.gray)

                        Slider(value: .constant(0.5))
                            .tint(.white)

                        Text("أ")
                            .font(.title3)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.08))
            )
        }
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Text("التفضيلات")
                .font(.subheadline)
                .foregroundStyle(.gray)

            VStack(spacing: 0) {
                // Haptics toggle
                SettingsRow(
                    title: "الاهتزاز عند التسبيح",
                    icon: "iphone.radiowaves.left.and.right",
                    iconBackground: .green
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.hapticsEnabled },
                        set: { viewModel.updateHapticsEnabled($0) }
                    ))
                    .labelsHidden()
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Notifications
                SettingsRow(
                    title: "التذكير",
                    icon: "bell.fill",
                    iconBackground: .red
                ) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.08))
            )
        }
    }

    // MARK: - Prayer Times Section
    private var prayerTimesSection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Text("مواقيت الصلاة")
                .font(.subheadline)
                .foregroundStyle(.gray)

            VStack(spacing: 0) {
                SettingsRow(
                    title: "طريقة الحساب",
                    icon: "clock.fill",
                    iconBackground: .blue
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .foregroundStyle(.gray)

                        Text(viewModel.calculationMethod.arabicName)
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.08))
            )
        }
    }

    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("لا حسابات - لا إعلانات")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Text("الإصدار ١.٠.٠")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}

// MARK: - Theme Button
struct ThemeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(white: 0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Row
struct SettingsRow<Accessory: View>: View {
    let title: String
    let icon: String
    let iconBackground: Color
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 12) {
            accessory()

            Spacer()

            Text(title)
                .font(.body)
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 8)
                .fill(iconBackground)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
        }
        .padding(16)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
