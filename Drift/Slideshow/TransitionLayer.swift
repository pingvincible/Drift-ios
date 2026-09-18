import SwiftUI

/// The set of transitions between frames, and the random pick among them.
///
/// Each slide carries the transition it *enters* with and the one it *leaves*
/// with, and the engine hands the same value to both sides of a swap, so the
/// outgoing and incoming halves always belong to the same transition.
enum SlideTransition: Equatable {
    /// Plain dissolve.
    case crossFade
    /// Out to black, then in from black.
    case dipToBlack
    /// The new frame pushes the old one off the given edge.
    case push(Edge)
    /// Slight scale plus dissolve.
    case zoomDissolve

    static let minimumDuration: TimeInterval = 1
    static let maximumDuration: TimeInterval = 2

    static func random() -> SlideTransition {
        switch Int.random(in: 0..<4) {
        case 0: return .crossFade
        case 1: return .dipToBlack
        case 2: return .push([Edge.leading, .trailing, .top, .bottom].randomElement() ?? .trailing)
        default: return .zoomDissolve
        }
    }

    /// Actual length of this transition, derived from the configured base and
    /// clamped to the 1...2 s the app allows.
    func duration(base: TimeInterval) -> TimeInterval {
        let scaled: TimeInterval
        switch self {
        case .crossFade: scaled = base
        case .dipToBlack: scaled = base * 1.3
        case .push: scaled = base * 0.85
        case .zoomDissolve: scaled = base * 1.1
        }
        return min(max(scaled, Self.minimumDuration), Self.maximumDuration)
    }

    func animation(base: TimeInterval) -> Animation {
        .easeInOut(duration: duration(base: base))
    }

    /// How the incoming frame arrives.
    func insertion(base: TimeInterval) -> AnyTransition {
        let duration = self.duration(base: base)
        switch self {
        case .crossFade:
            return .opacity
        case .dipToBlack:
            // The backdrop behind the slides is black, so fading the old one out
            // first and the new one in afterwards *is* the dip through black.
            return AnyTransition.opacity
                .animation(.easeIn(duration: duration / 2).delay(duration / 2))
        case .push(let edge):
            return .move(edge: edge)
        case .zoomDissolve:
            // Never below 1: a frame smaller than the screen would show bare
            // edges mid-transition.
            return AnyTransition.scale(scale: 1.08).combined(with: .opacity)
        }
    }

    /// How the outgoing frame leaves.
    func removal(base: TimeInterval) -> AnyTransition {
        let duration = self.duration(base: base)
        switch self {
        case .crossFade:
            return .opacity
        case .dipToBlack:
            return AnyTransition.opacity
                .animation(.easeOut(duration: duration / 2))
        case .push(let edge):
            return .move(edge: edge.opposite)
        case .zoomDissolve:
            return AnyTransition.scale(scale: 1.16).combined(with: .opacity)
        }
    }
}

private extension Edge {
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}
