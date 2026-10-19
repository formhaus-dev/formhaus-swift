@_spi(Renderer) import FormhausCore
import Testing

@testable import FormhausUI

@Suite("Inline images")
@MainActor
struct InlineImageTests {
    @Test("data images decode once and come from the cache")
    func decode() async {
        let first = await InlineImages.shared.image(swatch)
        #expect(first != nil)
        #expect(InlineImages.shared.cached(swatch) != nil)
        #expect(await InlineImages.shared.image("data:image/png;base64,AA==") == nil)
    }
}

@Suite("Inline images in views", .serialized)
@MainActor
struct InlineImageViewTests {
    @Test("picture options prefetch their inline images")
    func prefetch() async throws {
        let source = swatch.replacingOccurrences(of: "image/png", with: "image/x-png")
        let json: JSONValue = [
            "id": "p", "title": "P", "submit": ["label": "Send"],
            "fields": [["key": "c", "type": "radio", "label": "C", "options": [["value": "a", "label": "A", "image": .string(source)]]]],
        ]
        let model = FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
        let view = host(FormhausFormContent(model: model))
        for _ in 0..<40 where InlineImages.shared.cached(source) == nil { try await Task.sleep(for: .milliseconds(50)) }
        settle(view)
        #expect(InlineImages.shared.cached(source) != nil)
    }
}
