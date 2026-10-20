@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let definition: JSONValue = [
    "id": "p", "title": "P", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "one", "title": "One",
            "fields": [["key": "a", "type": "text", "label": "A"], ["key": "b", "type": "text", "label": "B"]],
        ],
        ["id": "two", "title": "Two", "fields": [["key": "c", "type": "text", "label": "C"]]],
    ],
]

@Suite("Step title error state", .serialized)
@MainActor
struct ProgressErrorTests {
    @Test("the progress context carries the current step error count and label", arguments: [false, true])
    func carriesErrors(marks: Bool) throws {
        let form = try model(definition)
        #expect(try context(form, marks: marks).errorCount == 0)
        #expect(try context(form, marks: marks).errorLabel == nil)
        form.setErrors(["a": "Bad", "b": "Bad"])
        let failing = try context(form, marks: marks)
        #expect(failing.errorCount == 2)
        #expect(failing.errorLabel == "Errors: 2")
        #expect((failing.steps != nil) == marks)
    }

    @Test("the count returns to zero once the errors are fixed")
    func clears() throws {
        let form = try model(definition)
        form.setErrors(["a": "Bad"])
        #expect(try context(form, marks: false).errorCount == 1)
        form.setErrors([:])
        let fixed = try context(form, marks: false)
        #expect(fixed.errorCount == 0)
        #expect(fixed.errorLabel == nil)
    }

    private func context(_ form: FormModel, marks: Bool) throws -> ProgressContext {
        var captured: ProgressContext?
        let components = FormComponents.standard.progress { context in
            captured = context
            return EmptyView()
        }
        _ = host(FormhausFormContent(model: form).formhausComponents(components).formhausBehavior(FormBehavior(stepErrorMarks: marks)))
        return try #require(captured)
    }
}
