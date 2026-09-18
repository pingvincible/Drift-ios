import SwiftUI

/// Full credit list for the cached photos of a theme.
///
/// The on-screen credit is deliberately brief, so this is where the whole list
/// of authors lives, with links back to Unsplash.
struct AttributionsView: View {
    let themeID: String

    @State private var attributions: [PhotoAttribution] = []
    @State private var isLoaded = false

    var body: some View {
        Group {
            if attributions.isEmpty && isLoaded {
                ContentUnavailableView(
                    "Пока пусто",
                    systemImage: "photo.on.rectangle",
                    description: Text("Здесь появятся авторы загруженных фотографий.")
                )
            } else {
                List(attributions, id: \.photoID) { attribution in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attribution.photographer)
                        HStack(spacing: 12) {
                            if let photoURL = attribution.photoURL {
                                Link("Фото", destination: photoURL)
                            }
                            if let authorURL = attribution.photographerURL {
                                Link("Профиль", destination: authorURL)
                            }
                        }
                        .font(.footnote)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Авторы")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            attributions = await AppServices.shared.cache.attributions(themeID: themeID)
            isLoaded = true
        }
    }
}
