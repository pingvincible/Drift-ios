import SwiftUI

/// The only screen with controls: pick a theme, set how long a frame lasts,
/// press Старт. After that the phone is not touched again.
struct HomeView: View {
    @Bindable var settings: SettingsStore
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            List {
                themeSection
                playbackSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Drift")
            .safeAreaInset(edge: .bottom) { startButton }
        }
    }

    private var themeSection: some View {
        Section {
            ForEach(Theme.builtIn) { theme in
                Button {
                    settings.themeID = theme.id
                } label: {
                    row(title: theme.title, isSelected: settings.themeID == theme.id)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Тема")
        } footer: {
            Text("Тема — это поисковый запрос к Unsplash.")
        }
    }

    private var playbackSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Кадр")
                    Spacer()
                    Text("\(Int(settings.slideDuration)) с")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $settings.slideDuration,
                    in: SettingsStore.slideDurationRange,
                    step: 1
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Показ")
        } footer: {
            Text("Сколько секунд держится один кадр.")
        }
    }

    private func row(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text("Старт")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

#Preview {
    HomeView(settings: SettingsStore(), onStart: {})
}
