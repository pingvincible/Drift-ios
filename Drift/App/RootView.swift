import SwiftUI

/// Root of the app. For now it is just the empty full-screen canvas the
/// slideshow will live on: no chrome, no status bar, no auto-lock.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Keep the screen awake only while the app is actually on screen,
            // so a backgrounded Drift never holds the device awake.
            IdleTimer.setDisabled(phase == .active)
        }
    }
}

#Preview {
    RootView()
}
