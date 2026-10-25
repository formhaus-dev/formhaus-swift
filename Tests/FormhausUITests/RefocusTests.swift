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
                [
                    "key": "people", "type": "group", "label": "People", "defaultItems": 1,
                    "fields": [["key": "name", "type": "text", "label": "Name"]],
                ],
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
        #expect(form.refocus(request, errorSummary: true, replacing: nil))
        #expect(form.field("b").focusToken == token + 1)
    }

    @Test("the field that had focus before the request does not block it")
    func replacesOldFocus() throws {
        let form = try model()
        form.field("a").noteFocus(true)
        form.focus(field: "b")
        let request = try #require(form.focusRequest)
        #expect(form.refocus(request, errorSummary: true, replacing: "a"))
    }

    @Test("a text field in a group item gets the request again")
    func groupItem() throws {
        let form = try model()
        form.focus(field: "people.0.name")
        #expect(form.refocus(try #require(form.focusRequest), errorSummary: true, replacing: nil))
        #expect(form.scrollSteps(to: "people.0.name").last?.id == "people.0.name")
    }

    @Test("a field focused after the request, a newer request or a choice field is left alone")
    func skips() throws {
        let form = try model()
        form.focus(field: "b")
        let request = try #require(form.focusRequest)
        form.field("a").noteFocus(true)
        #expect(!form.refocus(request, errorSummary: true, replacing: nil))
        form.field("a").noteFocus(false)
        form.focus(field: "a")
        #expect(!form.refocus(request, errorSummary: true, replacing: nil))
        form.focus(field: "c")
        #expect(!form.refocus(try #require(form.focusRequest), errorSummary: true, replacing: nil))
    }
}
