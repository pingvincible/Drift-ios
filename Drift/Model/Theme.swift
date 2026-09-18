import Foundation

/// A theme is nothing but a search query to Unsplash, plus a stable id used as
/// the name of its cache folder.
struct Theme: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let query: String
    var isCustom: Bool = false
}

extension Theme {
    static let carInteriors = Theme(id: "car-interiors", title: "Интерьеры автомобилей", query: "car interior")
    static let mountains = Theme(id: "mountains", title: "Горы", query: "mountains fog")
    static let forest = Theme(id: "forest", title: "Лес", query: "forest light")

    /// Starting set. Adding a theme here is all it takes to offer a new one.
    static let builtIn: [Theme] = [carInteriors, mountains, forest]

    static var `default`: Theme { carInteriors }

    /// Theme made from a query typed by hand.
    static func custom(query: String) -> Theme {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Theme(
            id: "custom-" + trimmed.cacheSlug,
            title: trimmed,
            query: trimmed,
            isCustom: true
        )
    }
}

extension String {
    /// File-system safe, stable across launches, readable enough to debug.
    ///
    /// Letters and digits survive (including Cyrillic), everything else becomes
    /// a dash. A short deterministic hash is appended so two queries that
    /// collapse to the same slug still get separate folders.
    var cacheSlug: String {
        var slug = ""
        var lastWasDash = false
        for character in lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character)
                lastWasDash = false
            } else if !lastWasDash {
                slug.append("-")
                lastWasDash = true
            }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.count > 32 {
            slug = String(slug.prefix(32))
        }
        let suffix = String(fnv1aHash, radix: 36)
        return slug.isEmpty ? suffix : "\(slug)-\(suffix)"
    }

    /// FNV-1a over the UTF-8 bytes. Unlike `hashValue` this is the same on
    /// every launch, which matters for folder names.
    private var fnv1aHash: UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }
}
