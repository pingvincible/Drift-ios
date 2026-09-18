import SwiftUI

/// Wraps the running slideshow: builds the engine for a theme, keeps it in sync
/// with the settings, and provides the only way out — a tap or a swipe.
struct SlideshowContainer: View {
    let theme: Theme
    let settings: SettingsStore
    let onExit: () -> Void

    @State private var engine: SlideshowEngine?

    var body: some View {
        ZStack {
            Color.black
            if let engine {
                SlideshowView(engine: engine)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onExit)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let travelled = max(abs(value.translation.width), abs(value.translation.height))
                if travelled > 60 { onExit() }
            }
        )
        .onAppear {
            guard engine == nil else { return }
            let engine = SlideshowEngine(source: AppServices.shared.makeSource(for: theme))
            engine.slideDuration = settings.slideDuration
            self.engine = engine
        }
        .onDisappear {
            engine?.stop()
            engine = nil
        }
        .onChange(of: settings.slideDuration) { _, duration in
            engine?.slideDuration = duration
        }
    }
}
