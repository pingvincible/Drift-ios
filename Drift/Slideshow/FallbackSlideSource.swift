import UIKit

/// Tries several sources in order and returns the first picture it gets.
///
/// This is what keeps the screen filled: network first, then whatever is on
/// disk, then the pictures shipped with the app.
@MainActor
final class FallbackSlideSource: SlideSource {
    private let sources: [SlideSource]

    init(_ sources: [SlideSource]) {
        self.sources = sources
    }

    func nextContent(target: SlideTarget) async -> SlideContent? {
        for source in sources {
            if let content = await source.nextContent(target: target) {
                return content
            }
        }
        return nil
    }
}
