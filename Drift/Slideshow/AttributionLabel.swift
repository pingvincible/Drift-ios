import SwiftUI

/// The photo credit Unsplash asks for.
///
/// Full-screen means no permanent chrome, so the credit appears quietly in the
/// corner for a few seconds at the start of each frame and then fades away. The
/// complete list of authors also lives in settings.
struct AttributionLabel: View {
    let attribution: PhotoAttribution

    /// How long the credit stays fully visible.
    static let visibleDuration: TimeInterval = 4
    private static let fadeDuration: TimeInterval = 1
    private static let delay: TimeInterval = 0.6

    @State private var isVisible = false

    var body: some View {
        Text(attribution.creditLine)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .shadow(color: .black.opacity(0.7), radius: 4, y: 1)
            .padding(.leading, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: Self.fadeDuration), value: isVisible)
            .allowsHitTesting(false)
            .task {
                try? await Task.sleep(for: .seconds(Self.delay))
                isVisible = true
                try? await Task.sleep(for: .seconds(Self.visibleDuration))
                isVisible = false
            }
    }
}
