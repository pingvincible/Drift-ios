import SwiftUI

/// The only screen with controls: pick a theme, set how long a frame lasts,
/// keep an eye on the cache, press Старт. After that the phone is not touched
/// again.
struct HomeView: View {
    @Bindable var settings: SettingsStore
    let onStart: () -> Void

    @State private var cacheStats = ImageCache.Stats()
    @State private var isConfirmingClear = false

    var body: some View {
        NavigationStack {
            List {
                themeSection
                playbackSection
                cacheSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Drift")
            .safeAreaInset(edge: .bottom) { startButton }
            .confirmationDialog(
                "Очистить кэш?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Очистить", role: .destructive) { clearCache() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все загруженные фотографии будут удалены с устройства.")
            }
            .task { await refreshCacheStats() }
        }
    }

    // MARK: - Theme

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
            customThemeRow
        } header: {
            Text("Тема")
        } footer: {
            Text("Тема — это поисковый запрос к Unsplash. Кэш у каждой темы свой.")
        }
    }

    private var customThemeRow: some View {
        HStack {
            TextField("Свой запрос", text: $settings.customQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { selectCustomTheme() }

            Button(action: selectCustomTheme) {
                Image(systemName: isCustomSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .opacity(isCustomSelected ? 1 : 0.35)
            }
            .buttonStyle(.plain)
            .disabled(trimmedCustomQuery.isEmpty)
        }
    }

    private var trimmedCustomQuery: String {
        settings.customQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCustomSelected: Bool {
        settings.themeID == SettingsStore.customThemeID && !trimmedCustomQuery.isEmpty
    }

    private func selectCustomTheme() {
        guard !trimmedCustomQuery.isEmpty else { return }
        settings.themeID = SettingsStore.customThemeID
    }

    // MARK: - Playback

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

    // MARK: - Cache

    private var cacheSection: some View {
        Section {
            HStack {
                Text("Занято")
                Spacer()
                Text(Int64(cacheStats.byteSize).formatted(.byteCount(style: .file)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Лимит")
                    Spacer()
                    Text("\(settings.cacheLimitMB) МБ")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: cacheLimitBinding, in: SettingsStore.cacheLimitRangeMB, step: 128)
            }
            .padding(.vertical, 4)

            NavigationLink("Авторы") {
                AttributionsView(themeID: settings.selectedTheme.id)
            }

            Button("Очистить кэш", role: .destructive) {
                isConfirmingClear = true
            }
        } header: {
            Text("Кэш")
        } footer: {
            Text("Загруженные фотографии хранятся на устройстве и показываются без сети. Когда лимит превышен, удаляются самые давние.")
        }
    }

    private var cacheLimitBinding: Binding<Double> {
        Binding(
            get: { Double(settings.cacheLimitMB) },
            set: { settings.cacheLimitMB = Int($0) }
        )
    }

    private func refreshCacheStats() async {
        cacheStats = await AppServices.shared.cache.stats()
    }

    private func clearCache() {
        Task {
            await AppServices.shared.cache.clear()
            await refreshCacheStats()
        }
    }

    // MARK: - Pieces

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
