@_spi(Renderer) import FormhausCore
import Testing

@testable import FormhausUI

private let crew: JSONValue = [
    "id": "crew", "title": "", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "one",
            "fields": [
                ["key": "name", "type": "text", "label": "Name", "validation": ["minLength": 3]],
                [
                    "key": "kids", "type": "group", "label": "Kids", "defaultItems": 1,
                    "fields": [["key": "kid", "type": "text", "label": "Kid"]],
                ],
            ],
        ],
        ["id": "two", "title": "Two", "fields": [["key": "city", "type": "text", "label": "City"]]],
    ],
]

@Suite("Locale changes on a live form")
@MainActor
struct LocaleModelTests {
    @Test("a new engine locale relabels the actions, labels and error summary and localizes the next messages")
    func swap() async throws {
        let form = try model(crew, values: ["name": "Ad"])
        await form.next()
        #expect(form.field("name").error == "Minimum length is 3")
        #expect(form.errorGroups.first?.title == "Step 1")
        let russian = try #require(LocaleCatalog.bundled("ru"))
        form.engine.locale = [russian]
        #expect(form.locale == [russian])
        #expect(form.actions.primaryLabel == "Далее")
        #expect(form.text(forLabel: "addItem") == "Добавить")
        #expect(form.errorGroups.first?.title == "Шаг 1")
        await form.next()
        #expect(form.field("name").error == "Не менее 3 символов")
    }

    @Test("the host pushes a changed locale through the handlers")
    func handlers() throws {
        let form = FormModel(definition: try FormDefinition(json: crew)) { _, _ in nil }
        #expect(form.actions.primaryLabel == "Continue")
        let german = LocaleCatalog(locale: "de", labels: ["continue": "Weiter"])
        form.updateHandlers(engineOptions: FormEngineOptions(locale: [german]))
        #expect(form.engine.locale == [german])
        #expect(form.actions.primaryLabel == "Weiter")
        form.updateHandlers(engineOptions: FormEngineOptions())
        #expect(form.actions.primaryLabel == "Continue")
    }

    @Test("validateWithRules runs onValidate when the step rules fail and follows the handlers")
    func validateWithRules() async throws {
        var calls = 0
        let onValidate: ValidateFn = { _, _ in
            calls += 1
            return ["": "Service down"]
        }
        let form = FormModel(
            definition: try FormDefinition(json: crew), initialValues: ["name": "Ad"],
            engineOptions: FormEngineOptions(onValidate: onValidate, validateWithRules: true)
        ) { _, _ in nil }
        await form.next()
        #expect(calls == 1)
        #expect(form.structure.currentStep?.id == "one")
        #expect(form.field("name").error != nil)
        #expect(form.topLevelErrors == ["Service down"])
        form.updateHandlers(engineOptions: FormEngineOptions(onValidate: onValidate))
        await form.next()
        #expect(calls == 1)
        #expect(form.topLevelErrors.isEmpty)
    }
}
