import UIKit

/// A picture ready to be shown, as handed over by a slide source.
struct SlideContent {
    /// Stable identity of the picture itself (photo id, file name, ...).
    let contentID: String
    let image: UIImage
    /// Credit line, when the picture came from Unsplash.
    let attribution: PhotoAttribution?

    init(contentID: String, image: UIImage, attribution: PhotoAttribution? = nil) {
        self.contentID = contentID
        self.image = image
        self.attribution = attribution
    }
}

/// One slide on screen: a picture, the motion it is animated with, and the two
/// transitions it enters and leaves with.
///
/// `id` is a per-appearance sequence number, not the photo id — the same photo
/// shown twice has to read as two different slides for SwiftUI transitions.
struct Slide: Identifiable {
    let id: Int
    let content: SlideContent
    let motion: KenBurnsMotion
    let enter: SlideTransition
    let exit: SlideTransition

    var contentID: String { content.contentID }
    var image: UIImage { content.image }
    var attribution: PhotoAttribution? { content.attribution }
}

/// Where the picture is going to be drawn: size in points plus the scale of
/// the display, which together give the pixel size to download.
struct SlideTarget: Equatable {
    var size: CGSize = .zero
    var scale: CGFloat = 3

    /// Portrait fallback used before the first layout pass.
    static let unknown = SlideTarget()

    /// Orientation tag. Pictures are cropped by Unsplash to the aspect of the
    /// screen, so the two orientations are cached as separate files.
    var variant: String { size.width > size.height ? "l" : "p" }
}

/// Anything that can produce the next picture for the slideshow.
///
/// Main-actor bound: sources are only ever driven by the engine, and the slow
/// parts (network, disk, decoding) are awaited on their own executors.
@MainActor
protocol SlideSource: AnyObject {
    /// Next picture to show, sized for `target` when the source can choose a
    /// resolution. Returns `nil` when nothing is available.
    func nextContent(target: SlideTarget) async -> SlideContent?
}
