@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormhausOptionImage: View {
    let key: ImageKey
    let contentMode: ContentMode

    public init(option: FieldOption, contentMode: ContentMode = .fill) {
        key = ImageKey(option.safeImage ?? "", digest: option.imageKey)
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let image = OptionImages.shared.loaded(key) {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
            }
        }
        .accessibilityHidden(true)
        .onAppear { OptionImages.shared.load(key) }
    }
}
