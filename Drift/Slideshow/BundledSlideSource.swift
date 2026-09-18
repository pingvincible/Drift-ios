import UIKit

/// Pictures shipped inside the app bundle.
///
/// Used before a theme is picked and as the last resort when there is neither
/// network nor cache, so the screen is never empty.
@MainActor
final class BundledSlideSource: SlideSource {
    private let names: [String]
    private var upcoming: [String] = []

    init(names: [String] = ["sample-dawn", "sample-ridge", "sample-pines", "sample-dusk"]) {
        self.names = names
    }

    func nextContent(target: SlideTarget) async -> SlideContent? {
        guard !names.isEmpty else { return nil }
        if upcoming.isEmpty {
            // Reshuffle, but never repeat the picture that is on screen right now.
            var reshuffled = names.shuffled()
            if names.count > 1, reshuffled.first == lastUsed {
                reshuffled.swapAt(0, reshuffled.count - 1)
            }
            upcoming = reshuffled
        }
        let name = upcoming.removeFirst()
        lastUsed = name

        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = await ImageLoader.decode(fileURL: url)
        else { return nil }

        return SlideContent(contentID: name, image: image)
    }

    private var lastUsed: String?
}
