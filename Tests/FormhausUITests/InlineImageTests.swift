@_spi(Renderer) import FormhausCore
import Testing

@testable import FormhausUI

@Suite("Inline images")
@MainActor
struct InlineImageTests {
    @Test("data images decode once and come from the cache")
    func decode() async {
        let key = ImageKey(swatch)
        #expect(await InlineImages.shared.image(key) != nil)
        #expect(InlineImages.shared.cached(key) != nil)
        #expect(await InlineImages.shared.image(ImageKey("data:image/png;base64,AA==")) == nil)
    }

    @Test("sources that share their length, start and end never share a cache entry")
    func collision() async {
        let head = String(repeating: "A", count: 200)
        let first = "data:image/png;base64," + head + "Q" + head
        let second = "data:image/png;base64," + head + "R" + head
        #expect(first.utf8.count == second.utf8.count)
        let one = FieldOption(value: "a", label: "A", image: first)
        let two = FieldOption(value: "b", label: "B", image: second)
        #expect(one.imageKey != two.imageKey)
        let firstKey = ImageKey(first, digest: one.imageKey)
        let secondKey = ImageKey(second, digest: two.imageKey)
        #expect(firstKey != secondKey)
        #expect(InlineImages.shared.entry(firstKey) !== InlineImages.shared.entry(secondKey))
        #expect(ImageKey(first) == firstKey)
        let pictured = swatch.replacingOccurrences(of: "image/png", with: "image/x-png")
        let decoded = await InlineImages.shared.image(ImageKey(pictured))
        #expect(decoded != nil)
        #expect(InlineImages.shared.cached(ImageKey(swatch)) !== decoded)
    }
}

@Suite("Inline images in views", .serialized)
@MainActor
struct InlineImageViewTests {
    @Test("picture options prefetch their inline images")
    func prefetch() async throws {
        let source = swatch.replacingOccurrences(of: "image/png", with: "image/pjpeg-png")
        let json: JSONValue = [
            "id": "p", "title": "P", "submit": ["label": "Send"],
            "fields": [["key": "c", "type": "radio", "label": "C", "options": [["value": "a", "label": "A", "image": .string(source)]]]],
        ]
        let model = FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
        let view = host(FormhausFormContent(model: model))
        for _ in 0..<40 where InlineImages.shared.cached(ImageKey(source)) == nil { try await Task.sleep(for: .milliseconds(50)) }
        settle(view)
        #expect(InlineImages.shared.cached(ImageKey(source)) != nil)
    }
}
