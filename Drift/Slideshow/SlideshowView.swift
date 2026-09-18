import SwiftUI

/// The slideshow itself: nothing but the picture, edge to edge.
struct SlideshowView: View {
    let engine: SlideshowEngine

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let slide = engine.current {
                    SlideView(slide: slide)
                        .id(slide.id)
                        .transition(
                            .asymmetric(
                                insertion: slide.enter.insertion(base: engine.transitionDuration),
                                removal: slide.exit.removal(base: engine.transitionDuration)
                            )
                        )

                    if let attribution = slide.attribution {
                        AttributionLabel(attribution: attribution)
                            .id(slide.id)
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                engine.target = SlideTarget(size: geo.size, scale: displayScale)
                engine.start()
            }
            .onChange(of: geo.size) { _, size in
                // Rotation only affects the resolution of the *next* frames;
                // the running slideshow is left alone.
                engine.target = SlideTarget(size: size, scale: displayScale)
            }
        }
        .ignoresSafeArea()
        .background(.black)
    }
}
