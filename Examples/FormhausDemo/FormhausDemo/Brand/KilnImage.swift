import FormhausUI
import ImageIO
import SwiftUI

struct KilnImage: View {
    @Environment(\.formhausTokens) private var tokens
    let source: String

    var body: some View {
        Color.clear
            .overlay {
                if let image = KilnImage.decode(source) {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
            }
            .background(tokens.colors.border)
            .accessibilityHidden(true)
    }

    private static let cache = NSCache<NSString, CGImage>()

    static func decode(_ source: String) -> CGImage? {
        if let cached = cache.object(forKey: source as NSString) { return cached }
        guard source.hasPrefix("data:image/"), let comma = source.firstIndex(of: ","),
            let data = Data(base64Encoded: String(source[source.index(after: comma)...])),
            let reader = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(reader, 0, nil)
        else { return nil }
        cache.setObject(image, forKey: source as NSString)
        return image
    }
}
