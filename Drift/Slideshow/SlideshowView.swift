import SwiftUI

/// The slideshow itself: nothing but the picture, edge to edge.
struct SlideshowView: View {
    let engine: SlideshowEngine

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
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                engine.targetSize = geo.size
                engine.start()
            }
            .onChange(of: geo.size) { _, size in
                // Rotation only affects the resolution of the *next* frames;
                // the running slideshow is left alone.
                engine.targetSize = size
            }
        }
        .ignoresSafeArea()
        .background(.black)
    }
}
