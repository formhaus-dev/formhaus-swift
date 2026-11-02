@_spi(Renderer) import FormhausCore
import FormhausUI
import Testing

private let rulesDefinition: JSONValue = [
    "formatVersion": "1.8", "id": "rules", "title": "Rules", "submit": ["label": "Save"],
    "fields": [
        ["key": "seats", "type": "number", "label": "Seats"],
        ["key": "account", "type": "text", "label": "Account", "readOnly": true],
        [
            "key": "plan", "type": "radio", "label": "Plan",
            "options": [
                ["value": "starter", "label": "Starter", "description": "Up to 5 seats", "disabled": [["field": "seats", "gt": 5]]],
                ["value": "pro", "label": "Pro"],
            ],
        ],
        [
            "key": "tasks", "type": "group", "label": "Tasks", "itemLabel": "Task {index}", "reorderable": true,
            "fields": [["key": "title", "type": "text", "label": "Title"]],
        ],
    ],
]

@Suite("Option rules, read-only fields and reorder")
@MainActor
struct OptionRulesModelTests {
    @Test("a read-only field ignores changes")
    func readOnly() throws {
        let form = try model(rulesDefinition, values: ["account": "acct-1"])
        let context = FieldContext(field: try #require(form.definition.allFields.first { $0.key == "account" }), model: form)
        #expect(context.readOnly)
        context.setValue("acct-2")
        #expect(form.engine.values["account"] == "acct-1")
    }

    @Test("a disabled option follows its conditions and cannot be chosen")
    func disabledOption() throws {
        let form = try model(rulesDefinition, values: ["seats": 8])
        let field = try #require(form.definition.allFields.first { $0.key == "plan" })
        let context = FieldContext(field: field, model: form)
        #expect(context.isDisabled(0) && !context.isDisabled(1))
        #expect(context.options[0].description == "Up to 5 seats")
        ChoiceSelection(context: context).choose("starter")
        #expect(form.engine.values["plan"] == nil)
        #expect(fires({ _ = FieldContext(field: field, model: form) }, when: { form.setValue(3, forKey: "seats") }))
        #expect(!FieldContext(field: field, model: form).isDisabled(0))
    }

    @Test("moving an item announces it and focuses the button that stays enabled")
    func move() throws {
        let form = try model(rulesDefinition, values: ["tasks": [["title": "A"], ["title": "B"], ["title": "C"]]])
        #expect(form.moveItem(0, to: 1, inGroup: "tasks"))
        #expect(form.engine.values["tasks"] == [["title": "B"], ["title": "A"], ["title": "C"]])
        #expect(form.focusRequest?.key == "tasks#down1")
        #expect(form.moveItem(1, to: 2, inGroup: "tasks"))
        #expect(form.focusRequest?.key == "tasks#up2")
        #expect(!form.moveItem(2, to: 3, inGroup: "tasks"))
    }

    @Test("a read-only form keeps its items in place")
    func readOnlyForm() throws {
        let form = try model(
            rulesDefinition, values: ["tasks": [["title": "A"], ["title": "B"]]], options: FormRendererOptions(readOnly: true))
        #expect(!form.moveItem(0, to: 1, inGroup: "tasks"))
        #expect(form.engine.values["tasks"] == [["title": "A"], ["title": "B"]])
    }
}
