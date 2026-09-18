import SwiftUI

/// Root of the app: the full-screen slideshow, no chrome, no auto-lock.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine = SlideshowEngine(source: RootView.makeSource(theme: .default))

    var body: some View {
        SlideshowView(engine: engine)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .onChange(of: scenePhase, initial: true) { _, phase in
                // Keep the screen awake only while the app is actually on
                // screen, so a backgrounded Drift never holds the device awake.
                IdleTimer.setDisabled(phase == .active)
            }
    }

    /// Unsplash first, the bundled pictures as the safety net.
    @MainActor
    private static func makeSource(theme: Theme) -> SlideSource {
        var sources: [SlideSource] = []
        if AppSecrets.hasUnsplashKey {
            let client = UnsplashClient(accessKey: AppSecrets.unsplashAccessKey)
            sources.append(UnsplashSlideSource(client: client, theme: theme))
        }
        sources.append(BundledSlideSource())
        return FallbackSlideSource(sources)
    }
}

#Preview {
    RootView()
}
