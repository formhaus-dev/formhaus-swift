@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormhausOptionImage: View {
    let key: ImageKey
    let contentMode: ContentMode

    public init(option: FieldOption, contentMode: ContentMode = .fill) {
        key = ImageKey(option.image ?? "", digest: option.imageKey)
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let image = InlineImages.shared.entry(key).image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
            } else if let url = URL(string: key.source), ["https", "http"].contains(url.scheme) {
                AsyncImage(url: url) { phase in phase.image?.resizable().aspectRatio(contentMode: contentMode) }
            }
        }
        .accessibilityHidden(true)
        .onAppear { InlineImages.shared.prefetch([key]) }
    }
}
