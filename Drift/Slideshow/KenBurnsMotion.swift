import Foundation
import CoreGraphics

/// One slide's slow zoom + pan.
///
/// The pan is stored in *unit* offsets: `-1...1` on each axis, where `1` means
/// "as far as this scale allows without uncovering an edge". A view with scale
/// `s` overhangs its frame by `(s - 1) / 2` on every side, so the safe offset is
/// that overhang. Both scale and offset are interpolated linearly by SwiftUI, and
/// the safe box grows linearly with the scale, so every intermediate frame of the
/// animation stays inside it too — the picture never shows a bare edge.
struct KenBurnsMotion: Equatable {
    var startScale: CGFloat
    var endScale: CGFloat
    var startUnitOffset: CGSize
    var endUnitOffset: CGSize
    var duration: TimeInterval

    func scale(atEnd: Bool) -> CGFloat {
        atEnd ? endScale : startScale
    }

    /// Pan offset in points for a slide drawn at `frame`.
    func offset(in frame: CGSize, atEnd: Bool) -> CGSize {
        let scale = self.scale(atEnd: atEnd)
        let unit = atEnd ? endUnitOffset : startUnitOffset
        let room = max(0, scale - 1) / 2
        return CGSize(
            width: unit.width * room * frame.width,
            height: unit.height * room * frame.height
        )
    }
}

extension KenBurnsMotion {
    /// Random zoom and pan for a single slide.
    ///
    /// The zoom always grows (roughly 1.0 -> 1.15); the starting point of the
    /// zoom and the direction of the pan are drawn fresh every time.
    static func random(duration: TimeInterval) -> KenBurnsMotion {
        let startScale = CGFloat.random(in: 1.0...1.04)
        let endScale = startScale + CGFloat.random(in: 0.11...0.16)

        let angle = Double.random(in: 0..<(2 * .pi))
        let direction = CGSize(width: CGFloat(cos(angle)), height: CGFloat(sin(angle)))
        let from = CGFloat.random(in: 0.2...0.6)
        let to = CGFloat.random(in: 0.7...1.0)

        return KenBurnsMotion(
            startScale: startScale,
            endScale: endScale,
            startUnitOffset: CGSize(
                width: -direction.width * from,
                height: -direction.height * from
            ),
            endUnitOffset: CGSize(
                width: direction.width * to,
                height: direction.height * to
            ),
            duration: duration
        )
    }
}
