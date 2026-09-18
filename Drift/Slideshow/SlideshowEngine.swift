import SwiftUI
import Observation

/// Drives the slideshow: asks the source for pictures, holds the frame that is
/// on screen, decides when to swap and with which transition.
@MainActor
@Observable
final class SlideshowEngine {
    /// The frame currently on screen.
    private(set) var current: Slide?
    /// Transition used for the swap that is running right now.
    private(set) var transition: SlideTransition = .crossFade

    /// How long a single frame stays on screen, in seconds.
    var slideDuration: TimeInterval = SlideshowEngine.defaultSlideDuration
    /// How long a swap takes, in seconds.
    var transitionDuration: TimeInterval = SlideshowEngine.defaultTransitionDuration
    /// Size of the screen in points; sources use it to pick a resolution.
    var targetSize: CGSize = .zero

    static let defaultSlideDuration: TimeInterval = 18
    static let defaultTransitionDuration: TimeInterval = 1.5

    private let source: SlideSource
    private var loop: Task<Void, Never>?
    private var sequence = 0

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
        let slide = Slide(
            id: sequence,
            content: content,
            // The motion has to outlast the frame itself: the picture keeps
            // moving while it is fading out under the next one.
            motion: .random(duration: slideDuration + transitionDuration * 2)
        )

        guard animated else {
            current = slide
            return
        }
        withAnimation(transition.animation(duration: transitionDuration)) {
            current = slide
        }
    }
}
