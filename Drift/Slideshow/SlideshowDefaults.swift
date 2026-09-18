import Foundation

/// Defaults shared by the engine and the settings store.
///
/// Deliberately not a member of either: the settings store is created off the
/// main actor, the engine lives on it, and a plain namespace is reachable from
/// both without any isolation dance.
enum SlideshowDefaults {
    /// Seconds one frame stays on screen.
    static let slideDuration: TimeInterval = 18
    /// Base seconds for a swap; each transition trims it to its own 1...2 s.
    static let transitionDuration: TimeInterval = 1.5
}
