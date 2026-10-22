import FormhausCore
import Testing

@testable import FormhausUI

private let identified: JSONValue = [
    "id": "t", "title": "T", "submit": ["label": "Send"],
    "fields": [["key": "swatch", "type": "x-swatch", "label": "Swatch"]],
]

@Suite("Test ids")
@MainActor
struct TestIdTests {
    @Test("automatic test ids follow the definition id")
    func automaticTestIds() throws {
        let definition = try FormDefinition(json: identified)
        let model = FormModel(definition: definition, options: FormRendererOptions(testIds: .automatic)) { _, _ in .ok }
        let field = try #require(model.structure.visibleFields.first)
        let context = FieldContext(field: field, model: model)
        #expect(context.testId == "t.swatch")
        #expect(context.optionTestId("pro") == "t.swatch.pro")
        #expect(FieldContext(field: field, key: "people.0.name", model: model).testId == "t.people.0.name")
        let actions = ActionsContext(state: model.actions, busy: false, model: model).testIds
        #expect(actions == ActionTestIds(submit: "t.submit", next: "t.next", back: "t.back", cancel: "t.cancel"))
        #expect(TestIdTarget(kind: .summary, definitionId: "t").defaultId == "t.summary")
        #expect(TestIdTarget(kind: .form, definitionId: "t").defaultId == "t.form")
    }

    @Test("test ids can be named by a closure and are off by default")
    func namedTestIds() throws {
        let definition = try FormDefinition(json: identified)
        let named = FormModel(
            definition: definition,
            options: FormRendererOptions(testIds: .custom { target in target.kind == .field ? "field-\(target.key ?? "")" : nil })
        ) { _, _ in .ok }
        let field = try #require(named.structure.visibleFields.first)
        #expect(FieldContext(field: field, model: named).testId == "field-swatch")
        #expect(FieldContext(field: field, model: named).optionTestId("a") == nil)
        let off = FormModel(definition: definition) { _, _ in .ok }
        #expect(FieldContext(field: field, model: off).testId == nil)
        #expect(ActionsContext(state: off.actions, busy: false, model: off).testIds.submit == nil)
    }
}
