import SwiftUI
import Observation

/// Drives the slideshow: asks the source for pictures, holds the frame that is
/// on screen, decides when to swap and with which transition.
@MainActor
@Observable
final class SlideshowEngine {
    /// The frame currently on screen.
    private(set) var current: Slide?

    /// How long a single frame stays on screen, in seconds.
    var slideDuration: TimeInterval = SlideshowEngine.defaultSlideDuration
    /// Base length of a swap, in seconds. Each transition scales it a little
    /// and clamps the result to 1...2 s.
    var transitionDuration: TimeInterval = SlideshowEngine.defaultTransitionDuration
    /// Size of the screen in points; sources use it to pick a resolution.
    var targetSize: CGSize = .zero

    static let defaultSlideDuration: TimeInterval = 18
    static let defaultTransitionDuration: TimeInterval = 1.5

    private let source: SlideSource
    private var loop: Task<Void, Never>?
    private var sequence = 0
    /// Transition the next frame will enter with. Picked one swap ahead so the
    /// leaving frame and the arriving one always use the same one.
    private var upcomingTransition: SlideTransition = .random()

    init(source: SlideSource) {
        self.source = source
    }

    var isRunning: Bool { loop != nil }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func run() async {
        var isFirstFrame = true
        while !Task.isCancelled {
            guard let content = await source.nextContent(targetSize: targetSize) else {
                // Nothing to show yet. Back off instead of spinning.
                guard await sleep(for: 2) else { return }
                continue
            }
            guard !Task.isCancelled else { return }

            show(content, animated: !isFirstFrame)
            isFirstFrame = false

            guard await sleep(for: slideDuration) else { return }
        }
    }

    /// Returns `false` when the loop was cancelled while waiting.
    private func sleep(for seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }

    private func show(_ content: SlideContent, animated: Bool) {
        sequence += 1
        let enter = upcomingTransition
        let exit = SlideTransition.random()
        upcomingTransition = exit

        let slide = Slide(
            id: sequence,
            content: content,
            // The motion has to outlast the frame itself: the picture keeps
            // moving while it is fading out under the next one.
            motion: .random(duration: slideDuration + SlideTransition.maximumDuration * 2),
            enter: enter,
            exit: exit
        )

        guard animated else {
            current = slide
            return
        }
        withAnimation(enter.animation(base: transitionDuration)) {
            current = slide
        }
    }
}
