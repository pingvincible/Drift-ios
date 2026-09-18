import SwiftUI

/// Root of the app: the full-screen slideshow, no chrome, no auto-lock.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine = SlideshowEngine(source: AppServices.shared.makeSource(for: .default))

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
}

#Preview {
    RootView()
}
