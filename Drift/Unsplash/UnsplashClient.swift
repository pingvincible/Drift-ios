import Foundation
import CoreGraphics

/// Talks to the Unsplash API: search, sized image URLs, download tracking.
actor UnsplashClient {
    enum ClientError: LocalizedError {
        case missingAccessKey
        case rateLimited
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingAccessKey: return "Не задан ключ Unsplash"
            case .rateLimited: return "Достигнут лимит запросов Unsplash"
            case .http(let code): return "Unsplash ответил \(code)"
            case .badResponse: return "Неожиданный ответ Unsplash"
            }
        }
    }

    enum Orientation: String {
        case portrait, landscape, squarish

        init(screenSize: CGSize) {
            if screenSize.height > screenSize.width {
                self = .portrait
            } else if screenSize.width > screenSize.height {
                self = .landscape
            } else {
                self = .squarish
            }
        }
    }

    /// Longest side Drift is ever willing to download, in pixels. Keeps both the
    /// traffic and the cache sane on the phones that ask for 3x of a tall screen.
    static let maximumPixelSide: CGFloat = 2400
    /// Extra resolution for the Ken Burns zoom, so the picture does not go soft
    /// at the end of the movement.
    static let zoomHeadroom: CGFloat = 1.2

    private let accessKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private static let apiRoot = URL(string: "https://api.unsplash.com")!

    init(accessKey: String, session: URLSession = .drift) {
        self.accessKey = accessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    var isConfigured: Bool { !accessKey.isEmpty }

    // MARK: - Search

    func searchPhotos(
        query: String,
        page: Int = 1,
        perPage: Int = 30,
        orientation: Orientation? = nil
    ) async throws -> UnsplashSearchResponse {
        guard isConfigured else { throw ClientError.missingAccessKey }

        var components = URLComponents(
            url: Self.apiRoot.appendingPathComponent("search/photos"),
            resolvingAgainstBaseURL: false
        )
        var items = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "per_page", value: String(min(max(1, perPage), 30))),
            URLQueryItem(name: "content_filter", value: "high"),
        ]
        if let orientation {
            items.append(URLQueryItem(name: "orientation", value: orientation.rawValue))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw ClientError.badResponse }

        let (data, response) = try await session.data(for: authorized(URLRequest(url: url)))
        try Self.validate(response)
        do {
            return try decoder.decode(UnsplashSearchResponse.self, from: data)
        } catch {
            throw ClientError.badResponse
        }
    }

    // MARK: - Images

    /// Download the bytes of `photo` at a resolution that suits `targetSize`.
    func imageData(for photo: UnsplashPhoto, targetSize: CGSize, scale: CGFloat) async throws -> Data {
        let url = Self.imageURL(for: photo, targetSize: targetSize, scale: scale)
        let (data, response) = try await session.data(from: url)
        try Self.validate(response)
        return data
    }

    /// Unsplash requires this to be called whenever a photo is actually shown.
    /// Best effort: a failure here must never interrupt the slideshow.
    func trackDownload(_ photo: UnsplashPhoto) async {
        guard isConfigured else { return }
        var request = authorized(URLRequest(url: photo.links.downloadLocation))
        request.httpMethod = "GET"
        _ = try? await session.data(for: request)
    }

    // MARK: - URL building

    /// Sizing parameters are appended to the `raw` URL, which is what Unsplash
    /// documents for dynamically resized images.
    static func imageURL(for photo: UnsplashPhoto, targetSize: CGSize, scale: CGFloat) -> URL {
        let pixels = pixelSize(targetSize: targetSize, scale: scale)
        guard var components = URLComponents(url: photo.urls.raw, resolvingAgainstBaseURL: false) else {
            return photo.urls.regular
        }
        var items = components.queryItems ?? []
        // `raw` already carries tracking parameters; keep them and add ours.
        items.removeAll { ["w", "h", "fit", "crop", "q", "fm", "dpr"].contains($0.name) }
        items.append(contentsOf: [
            URLQueryItem(name: "w", value: String(Int(pixels.width))),
            URLQueryItem(name: "h", value: String(Int(pixels.height))),
            URLQueryItem(name: "fit", value: "crop"),
            URLQueryItem(name: "crop", value: "entropy"),
            URLQueryItem(name: "q", value: "80"),
            URLQueryItem(name: "fm", value: "jpg"),
        ])
        components.queryItems = items
        return components.url ?? photo.urls.regular
    }

    /// Screen points -> pixels to ask Unsplash for, with zoom headroom and a cap.
    static func pixelSize(targetSize: CGSize, scale: CGFloat) -> CGSize {
        let fallback = CGSize(width: 1170, height: 2532)
        var size = targetSize.width > 0 && targetSize.height > 0 ? targetSize : fallback
        size = CGSize(
            width: size.width * max(scale, 1) * zoomHeadroom,
            height: size.height * max(scale, 1) * zoomHeadroom
        )
        let longest = max(size.width, size.height)
        if longest > maximumPixelSide {
            let k = maximumPixelSide / longest
            size = CGSize(width: size.width * k, height: size.height * k)
        }
        return CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))
    }

    // MARK: - Plumbing

    private func authorized(_ request: URLRequest) -> URLRequest {
        var request = request
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        switch http.statusCode {
        case 200..<300:
            return
        case 403:
            // Unsplash reports an exhausted hourly quota as a 403.
            let remaining = http.value(forHTTPHeaderField: "X-Ratelimit-Remaining")
            throw remaining == "0" ? ClientError.rateLimited : ClientError.http(403)
        case 429:
            throw ClientError.rateLimited
        default:
            throw ClientError.http(http.statusCode)
        }
    }
}

extension URLSession {
    /// Session used for every Unsplash call. Drift keeps its own disk cache, so
    /// the URL cache is switched off to avoid storing everything twice.
    static let drift: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
}
