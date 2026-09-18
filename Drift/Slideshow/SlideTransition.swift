import SwiftUI

/// How one slide gives way to the next.
enum SlideTransition: CaseIterable {
    /// Plain dissolve. Always in the mix.
    case crossFade

    func transition(duration: TimeInterval) -> AnyTransition {
        switch self {
        case .crossFade:
            return .opacity
        }
    }

    /// The animation curve the swap itself is driven with.
    func animation(duration: TimeInterval) -> Animation {
        .easeInOut(duration: duration)
    }

    static func random() -> SlideTransition {
        allCases.randomElement() ?? .crossFade
    }
}
