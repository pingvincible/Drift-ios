import UIKit

/// Decoding helpers. Everything happens off the main actor and the result is
/// force-decoded, so handing an image to SwiftUI never costs a dropped frame.
enum ImageLoader {
    static func decode(data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data) else { return nil }
            return image.preparingForDisplay() ?? image
        }.value
    }

    static func decode(fileURL: URL) async -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return await decode(data: data)
    }
}
