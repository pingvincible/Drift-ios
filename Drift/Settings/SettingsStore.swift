import Foundation
import Observation

/// Everything the user can change, kept in `UserDefaults`.
@Observable
final class SettingsStore {
    /// Sentinel id meaning "use `customQuery`".
    static let customThemeID = "custom"

    /// Bounds offered by the settings screen.
    static let slideDurationRange: ClosedRange<Double> = 5...60

    var themeID: String {
        didSet { defaults.set(themeID, forKey: Key.themeID) }
    }

    var customQuery: String {
        didSet { defaults.set(customQuery, forKey: Key.customQuery) }
    }

    /// How long one frame stays on screen, in seconds.
    var slideDuration: Double {
        didSet {
            slideDuration = min(max(slideDuration, Self.slideDurationRange.lowerBound),
                                Self.slideDurationRange.upperBound)
            defaults.set(slideDuration, forKey: Key.slideDuration)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        themeID = defaults.string(forKey: Key.themeID) ?? Theme.default.id
        customQuery = defaults.string(forKey: Key.customQuery) ?? ""
        let storedDuration = defaults.object(forKey: Key.slideDuration) as? Double
        slideDuration = storedDuration ?? SlideshowEngine.defaultSlideDuration
    }

    /// Theme the slideshow should play.
    var selectedTheme: Theme {
        if themeID == Self.customThemeID {
            let query = customQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty { return .custom(query: query) }
        }
        return Theme.builtIn.first { $0.id == themeID } ?? .default
    }

    private enum Key {
        static let themeID = "theme.id"
        static let customQuery = "theme.customQuery"
        static let slideDuration = "slideshow.slideDuration"
    }
}
