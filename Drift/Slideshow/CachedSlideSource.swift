import UIKit

/// Slides read straight off the disk cache.
///
/// This is what plays when there is no network: no requests, no errors, no
/// pauses — just whatever the theme has collected so far.
@MainActor
final class CachedSlideSource: SlideSource {
    private let cache: ImageCache
    private let themeID: String
    private var upcoming: [ImageCache.Entry] = []

    init(cache: ImageCache, themeID: String) {
        self.cache = cache
        self.themeID = themeID
    }

    func nextContent(target: SlideTarget) async -> SlideContent? {
        for _ in 0..<3 {
            if upcoming.isEmpty {
                upcoming = await cache.entries(themeID: themeID).shuffled()
            }
            guard !upcoming.isEmpty else { return nil }
            let entry = upcoming.removeFirst()

            guard let data = await cache.data(for: entry.key),
                  let image = await ImageLoader.decode(data: data)
            else { continue }

            return SlideContent(
                contentID: entry.key.photoID,
                image: image,
                attribution: await cache.attribution(for: entry.key)
            )
        }
        return nil
    }
}
