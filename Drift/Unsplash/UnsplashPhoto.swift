import Foundation

/// A photo as returned by the Unsplash search endpoint.
///
/// Only the fields Drift actually uses are decoded.
struct UnsplashPhoto: Decodable, Identifiable, Hashable {
    let id: String
    let width: Int
    let height: Int
    let color: String?
    let description: String?
    let altDescription: String?
    let urls: Urls
    let links: Links
    let user: User

    struct Urls: Decodable, Hashable {
        /// Base URL the sizing parameters are appended to.
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
    }

    struct Links: Decodable, Hashable {
        /// Public page of the photo — part of the required attribution.
        let html: URL
        /// Endpoint that must be pinged whenever the photo is actually used.
        let downloadLocation: URL
    }

    struct User: Decodable, Hashable {
        let name: String
        let username: String
        let links: UserLinks

        struct UserLinks: Decodable, Hashable {
            let html: URL
        }
    }

    var attribution: PhotoAttribution {
        PhotoAttribution(
            photoID: id,
            photographer: user.name,
            photographerURL: user.links.html,
            photoURL: links.html
        )
    }
}

struct UnsplashSearchResponse: Decodable {
    let total: Int
    let totalPages: Int
    let results: [UnsplashPhoto]
}

/// Credit line for a photo. Stored next to the cached file so the author is
/// still known when the app is offline.
struct PhotoAttribution: Codable, Hashable {
    let photoID: String
    let photographer: String
    let photographerURL: URL?
    let photoURL: URL?

    /// Short line for the on-screen credit.
    var creditLine: String { "\(photographer) · Unsplash" }
}
