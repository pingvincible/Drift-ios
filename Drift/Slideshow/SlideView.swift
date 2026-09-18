import SwiftUI

/// A single full-screen frame with the Ken Burns effect.
///
/// The zoom and the pan run for the whole time the slide is on screen, linearly,
/// so the motion never speeds up or stalls.
struct SlideView: View {
    let slide: Slide

    @State private var atEnd = false

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: slide.image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(slide.motion.scale(atEnd: atEnd))
                .offset(slide.motion.offset(in: geo.size, atEnd: atEnd))
                // Scoped to `atEnd` so the transition between slides, which runs
                // on its own animation, never drags the Ken Burns timing with it.
                .animation(.linear(duration: slide.motion.duration), value: atEnd)
        }
        .clipped()
        .onAppear { atEnd = true }
    }
}
