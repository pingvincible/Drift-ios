import SwiftUI

/// Root of the app: the settings screen, and the full-screen slideshow on top
/// of it once it is started.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = SettingsStore()
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isPlaying {
                SlideshowContainer(theme: settings.selectedTheme, settings: settings) {
                    withAnimation(.easeInOut(duration: 0.35)) { isPlaying = false }
                }
                .id(settings.selectedTheme.id)
                .transition(.opacity)
            } else {
                HomeView(settings: settings) {
                    withAnimation(.easeInOut(duration: 0.6)) { isPlaying = true }
                }
                .transition(.opacity)
            }
        }
        // Chrome disappears only while the slideshow runs.
        .statusBarHidden(isPlaying)
        .persistentSystemOverlays(isPlaying ? .hidden : .automatic)
        .onChange(of: scenePhase, initial: true) { _, _ in updateIdleTimer() }
        .onChange(of: isPlaying) { _, _ in updateIdleTimer() }
    }

    /// Auto-lock is off only while the slideshow is actually on screen.
    private func updateIdleTimer() {
        IdleTimer.setDisabled(isPlaying && scenePhase == .active)
    }
}

#Preview {
    RootView()
}
