import UIKit

/// Slides for one theme, taken from Unsplash.
@MainActor
final class UnsplashSlideSource: SlideSource {
    /// Something the UI may want to show or log; never interrupts the slideshow.
    private(set) var lastError: Error?

    private let client: UnsplashClient
    private let theme: Theme

    private var queue: [UnsplashPhoto] = []
    private var page = 1
    private var knownPages = 1
    private var isExhausted = false

    /// Search results are 30 per page; walking more pages than this would burn
    /// the hourly API quota for very little variety.
    private static let maximumPages = 8
    private static let perPage = 30

    init(client: UnsplashClient, theme: Theme) {
        self.client = client
        self.theme = theme
    }

    func nextContent(target: SlideTarget) async -> SlideContent? {
        // A photo can fail to download on its own; try a couple of others before
        // telling the engine there is nothing to show.
        for _ in 0..<3 {
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
        do {
            let data = try await client.imageData(
                for: photo,
                targetSize: target.size,
                scale: target.scale
            )
            guard let image = await ImageLoader.decode(data: data) else { return nil }
            // Required by the Unsplash API guidelines: report every photo that
            // is actually put on screen.
            Task { await client.trackDownload(photo) }
            return SlideContent(
                contentID: photo.id,
                image: image,
                attribution: photo.attribution
            )
        } catch {
            lastError = error
            return nil
        }
    }

    private func refill(target: SlideTarget) async {
        guard !isExhausted else { return }
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
        } catch {
            lastError = error
            if case UnsplashClient.ClientError.missingAccessKey = error {
                isExhausted = true
            }
        }
    }
}
