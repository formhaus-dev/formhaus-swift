@_spi(Renderer) import FormhausCore
import Testing

@testable import FormhausUI

@Suite("Repeating a focus request")
@MainActor
struct RefocusTests {
    private func model() throws -> FormModel {
        let definition: JSONValue = [
            "id": "r", "title": "R", "submit": ["label": "Send"],
            "fields": [["key": "a", "type": "text", "label": "A"], ["key": "b", "type": "text", "label": "B"]],
        ]
        return FormModel(definition: try FormDefinition(json: definition)) { _, _ in nil }
    }

    @Test("a request the field did not take is sent to it again")
    func repeats() throws {
        let form = try model()
        form.focus(field: "b")
        let request = try #require(form.focusRequest)
        let token = form.field("b").focusToken
        form.refocus(request)
        #expect(form.field("b").focusToken == token + 1)
    }

    @Test("a focused field, a newer request or a dropped request is left alone")
    func skips() throws {
        let form = try model()
        form.focus(field: "b")
        let request = try #require(form.focusRequest)
        form.field("b").noteFocus(true)
        let token = form.field("b").focusToken
        form.refocus(request)
        #expect(form.field("b").focusToken == token)
        form.field("b").noteFocus(false)
        form.focus(field: "a")
        form.refocus(request)
        #expect(form.field("b").focusToken == token)
        form.dropFocusRequest()
        form.refocus(request)
        #expect(form.field("b").focusToken == token)
    }
}
