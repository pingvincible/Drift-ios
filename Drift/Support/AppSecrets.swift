import Foundation

/// Build-time configuration that must not live in the repository.
///
/// The key travels from `Config/Secrets.xcconfig` through `Info.plist`.
enum AppSecrets {
    private static let placeholder = "your_unsplash_access_key_here"

    static var unsplashAccessKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "UnsplashAccessKey") as? String ?? ""
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return key == placeholder ? "" : key
    }

    static var hasUnsplashKey: Bool { !unsplashAccessKey.isEmpty }
}
