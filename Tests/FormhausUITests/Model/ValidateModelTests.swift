@_spi(Renderer) import FormhausCore
import FormhausUI
import Testing

private let wizard: JSONValue = [
    "id": "wizard", "title": "", "submit": ["label": "Send"],
    "steps": [
        ["id": "one", "title": "One", "fields": [["key": "name", "type": "text", "label": "Name", "validation": ["required": true]]]],
        ["id": "two", "title": "Two", "fields": [["key": "plan", "type": "text", "label": "Plan"]]],
        ["id": "three", "title": "Three", "fields": [["key": "city", "type": "text", "label": "City"]]],
    ],
]

private let filled: JSONObject = ["name": "Ada", "plan": "a", "city": "Oslo"]

@MainActor
private func form(_ options: FormEngineOptions, _ definition: JSONValue = wizard, values: JSONObject = filled) throws -> FormModel {
    FormModel(definition: try FormDefinition(json: definition), initialValues: values, engineOptions: options) { _, _ in nil }
}

@MainActor
private final class Service {
    var down = true
}

@Suite("onValidate in the renderer")
@MainActor
struct ValidateModelTests {
    @Test("shows onValidate errors of the step and focuses the field")
    func stepErrors() async throws {
        var contexts: [ValidateContext] = []
        let form = try form(
            FormEngineOptions(onValidate: { _, context in
                contexts.append(context)
                return ["name": "Taken"]
            }))
        await form.next()
        #expect(form.field("name").error == "Taken")
        #expect(form.structure.currentStep?.id == "one")
        #expect(form.focusRequest?.key == "name")
        #expect(contexts.map(\.fields) == [["name"]])
    }

    @Test("opens the step of an onValidate error on submit and shows keys outside the form as form errors")
    func submitErrors() async throws {
        var sent = 0
        let form = FormModel(
            definition: try FormDefinition(json: wizard), initialValues: filled,
            engineOptions: FormEngineOptions(onValidate: { _, context in context.submit ? ["name": "Taken", "": "Try again later"] : nil })
        ) { _, _ in
            sent += 1
            return nil
        }
        await form.next()
        await form.next()
        #expect(form.structure.currentStep?.id == "three")
        await form.submit()
        #expect(form.structure.currentStep?.id == "one")
        #expect(form.topLevelErrors == ["Try again later"])
        #expect(form.errorGroups.flatMap(\.entries).map(\.text) == ["Name: Taken"])
        #expect(form.focusRequest?.key == "name")
        #expect(sent == 0)
    }

    @Test("clears onValidate form errors on the next Continue and on Back")
    func clears() async throws {
        let service = Service()
        let form = try form(
            FormEngineOptions(onValidate: { _, context in service.down || context.stepId == "two" ? ["": "Service down"] : nil }))
        await form.next()
        #expect(form.topLevelErrors == ["Service down"])
        service.down = false
        await form.next()
        #expect(form.structure.currentStep?.id == "two")
        #expect(form.topLevelErrors.isEmpty)
        await form.next()
        #expect(form.topLevelErrors == ["Service down"])
        await form.back()
        #expect(form.structure.currentStep?.id == "one")
        #expect(form.topLevelErrors.isEmpty)
    }

    @Test("localizes validation messages with plural forms and labels from a locale catalog")
    func locale() async throws {
        let russian = try #require(LocaleCatalog.bundled("ru"))
        var definition = try #require(wizard.objectValue)
        definition["fields"] = [
            ["key": "name", "type": "text", "label": "Name", "validation": ["minLength": 3]],
            [
                "key": "kids", "type": "group", "label": "Kids", "defaultItems": 1,
                "fields": [["key": "kid", "type": "text", "label": "Kid"]],
            ],
        ]
        definition["steps"] = nil
        let german = LocaleCatalog(locale: "de", labels: ["submit": "Senden", "addItem": "Hinzufügen"])
        let form = try form(FormEngineOptions(locale: [german, russian]), .object(definition), values: ["name": "Ad"])
        #expect(form.text(forLabel: "addItem") == "Hinzufügen")
        #expect(form.text(forLabel: "removeItemNamed", ["label": "Удалить", "item": "Kids 1"]) == "Удалить «Kids 1»")
        #expect(form.text(forLabel: "stepOf", ["current": 1, "total": 3]) == "Шаг 1 из 3")
        await form.submit()
        #expect(form.field("name").error == "Не менее 3 символов")
        #expect(form.errorGroups.first?.entries.first?.text == "Name: Не менее 3 символов")
    }
}
