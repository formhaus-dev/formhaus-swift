@_spi(Renderer) import FormhausCore
import Testing

@testable import FormhausUI

@Suite("Repeating a focus request")
@MainActor
struct RefocusTests {
    private func model() throws -> FormModel {
        let definition: JSONValue = [
            "id": "r", "title": "R", "submit": ["label": "Send"],
            "fields": [
                ["key": "a", "type": "text", "label": "A"], ["key": "b", "type": "text", "label": "B"],
                ["key": "c", "type": "radio", "label": "C", "options": [["value": "x", "label": "X"]]],
            ],
        ]
        return FormModel(definition: try FormDefinition(json: definition)) { _, _ in nil }
    }

    @Test("a text field that did not take the request gets it again")
    func repeats() throws {
        let form = try model()
        form.focus(field: "b")
        let request = try #require(form.focusRequest)
        let token = form.field("b").focusToken
        #expect(form.refocus(request))
        #expect(form.field("b").focusToken == token + 1)
    }

    @Test("a focused field, a newer request or a choice field is left alone")
    func skips() throws {
        let form = try model()
        form.focus(field: "b")
        let request = try #require(form.focusRequest)
        form.field("a").noteFocus(true)
        #expect(!form.refocus(request))
        form.field("a").noteFocus(false)
        form.focus(field: "a")
        #expect(!form.refocus(request))
        form.focus(field: "c")
        #expect(!form.refocus(try #require(form.focusRequest)))
    }
}
