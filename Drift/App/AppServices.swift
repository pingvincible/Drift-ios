import Foundation

/// The long-lived pieces the whole app shares: the disk cache and the API
/// client. Both are actors, so passing them around is safe.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let cache: ImageCache
    let client: UnsplashClient

    private init() {
        cache = ImageCache()
        client = UnsplashClient(accessKey: AppSecrets.unsplashAccessKey)
    }

    /// Pushes the user's disk budget down to the cache, trimming it if needed.
    func applyCacheLimit(megabytes: Int) {
        Task { await cache.setLimit(bytes: megabytes * 1024 * 1024) }
    }

    /// The chain the slideshow pulls frames from: network first, then the disk
    /// cache, then the pictures shipped with the app.
    func makeSource(for theme: Theme) -> SlideSource {
        FallbackSlideSource([
            UnsplashSlideSource(client: client, cache: cache, theme: theme),
            CachedSlideSource(cache: cache, themeID: theme.id),
            BundledSlideSource(),
        ])
    }
}
