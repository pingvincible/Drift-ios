import UIKit

/// Slides for one theme, taken from Unsplash and written to the disk cache on
/// the way through.
@MainActor
final class UnsplashSlideSource: SlideSource {
    /// Last thing that went wrong. Kept for the settings screen; the slideshow
    /// itself never stops because of it.
    private(set) var lastError: Error?

    private let client: UnsplashClient
    private let cache: ImageCache?
    private let theme: Theme

    private var queue: [UnsplashPhoto] = []
    private var page = 1
    private var knownPages = 1
    private var isExhausted = false
    /// Set after a failure so a dead network is not retried on every frame —
    /// the cache takes over in the meantime.
    private var retryAfter: Date?

    /// Search results are 30 per page; walking more pages than this would burn
    /// the hourly API quota for very little variety.
    private static let maximumPages = 8
    private static let perPage = 30
    private static let networkBackoff: TimeInterval = 45
    private static let rateLimitBackoff: TimeInterval = 15 * 60

    init(client: UnsplashClient, cache: ImageCache?, theme: Theme) {
        self.client = client
        self.cache = cache
        self.theme = theme
    }

    func nextContent(target: SlideTarget) async -> SlideContent? {
        // A single photo can fail on its own; try a couple of others before
        // handing the frame over to the cache.
        for _ in 0..<3 {
            guard !isBackingOff else { return nil }
            if queue.isEmpty {
                await refill(target: target)
            }
            guard !queue.isEmpty else { return nil }

            let photo = queue.removeFirst()
            if let content = await load(photo, target: target) {
                return content
            }
        }
        return nil
    }

    // MARK: - Loading

    private func load(_ photo: UnsplashPhoto, target: SlideTarget) async -> SlideContent? {
        let key = ImageCache.Key(themeID: theme.id, photoID: photo.id, variant: target.variant)

        if let cache, let data = await cache.data(for: key),
           let image = await ImageLoader.decode(data: data) {
            return SlideContent(contentID: photo.id, image: image, attribution: photo.attribution)
        }

        do {
            let data = try await client.imageData(
                for: photo,
                targetSize: target.size,
                scale: target.scale
            )
            guard let image = await ImageLoader.decode(data: data) else { return nil }
            await cache?.store(data, attribution: photo.attribution, for: key)
            // Required by the Unsplash API guidelines. Fired when the photo is
            // really fetched — a re-run from the cache does not hit the endpoint
            // again, which would eat the hourly quota within the hour.
            Task { await client.trackDownload(photo) }
            return SlideContent(contentID: photo.id, image: image, attribution: photo.attribution)
        } catch {
            note(error)
            return nil
        }
    }

    private func refill(target: SlideTarget) async {
        guard !isBackingOff else { return }
        do {
            let response = try await client.searchPhotos(
                query: theme.query,
                page: page,
                perPage: Self.perPage,
                orientation: UnsplashClient.Orientation(screenSize: target.size)
            )
            knownPages = max(1, min(response.totalPages, Self.maximumPages))
            queue = response.results.shuffled()
            if response.results.isEmpty {
                // Nothing on the very first page means the query itself is
                // empty; anything else is just the end of the pages.
                if page == 1 { isExhausted = true } else { page = 1 }
            } else {
                page = page >= knownPages ? 1 : page + 1
            }
            lastError = nil
            retryAfter = nil
        } catch {
            note(error)
        }
    }

    // MARK: - Back-off

    private var isBackingOff: Bool {
        if isExhausted { return true }
        if let retryAfter, retryAfter > Date() { return true }
        return false
    }

    private func note(_ error: Error) {
        lastError = error
        switch error as? UnsplashClient.ClientError {
        case .missingAccessKey:
            isExhausted = true
        case .rateLimited:
            retryAfter = Date().addingTimeInterval(Self.rateLimitBackoff)
        default:
            retryAfter = Date().addingTimeInterval(Self.networkBackoff)
        }
    }
}
