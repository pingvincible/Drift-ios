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
    /// Where the frames are drawn; sources use it to pick a resolution.
    var target: SlideTarget = .unknown

    static let defaultSlideDuration: TimeInterval = 18
    static let defaultTransitionDuration: TimeInterval = 1.5

    private let source: SlideSource
    private var loop: Task<Void, Never>?
    /// The frame being fetched while the current one is on screen.
    private var prefetch: Task<SlideContent?, Never>?
    private var sequence = 0
    /// Transition the next frame will enter with. Picked one swap ahead so the
    /// leaving frame and the arriving one always use the same one. The very
    /// first frame always fades up from black.
    private var upcomingTransition: SlideTransition = .crossFade

    /// How long to wait before asking again when no source had anything.
    private static let emptyRetryDelay: TimeInterval = 2

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
        prefetch?.cancel()
        prefetch = nil
    }

    private func run() async {
        while !Task.isCancelled {
            // Either the frame that was fetched while the previous one was on
            // screen, or — for the very first frame — a fresh fetch.
            let pending = prefetch ?? makePrefetch()
            prefetch = nil

            guard let content = await pending.value else {
                // Nothing anywhere yet. Back off instead of spinning.
                guard await sleep(for: Self.emptyRetryDelay) else { return }
                continue
            }
            guard !Task.isCancelled else { return }

            show(content)

            // Start on the next frame immediately: by the time the timer fires
            // the picture is decoded and ready, so no loading is ever on screen.
            prefetch = makePrefetch()

            guard await sleep(for: slideDuration) else { return }
        }
    }

    private func makePrefetch() -> Task<SlideContent?, Never> {
        let target = self.target
        let source = self.source
        return Task { await source.nextContent(target: target) }
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

    private func show(_ content: SlideContent) {
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

        withAnimation(enter.animation(base: transitionDuration)) {
            current = slide
        }
    }
}
