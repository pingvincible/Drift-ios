import UIKit

/// A picture ready to be shown, as handed over by a slide source.
struct SlideContent {
    /// Stable identity of the picture itself (photo id, file name, ...).
    let contentID: String
    let image: UIImage
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
}

/// Anything that can produce the next picture for the slideshow.
protocol SlideSource: AnyObject {
    /// Next picture to show, sized for `targetSize` in points when the source
    /// can choose a resolution. Returns `nil` when nothing is available.
    func nextContent(targetSize: CGSize) async -> SlideContent?
}
