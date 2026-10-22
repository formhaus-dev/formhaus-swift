import Testing

@testable import FormhausCore

private let guests: JSONValue = [
    "formatVersion": "1.5", "id": "f", "title": "F", "submit": ["label": "Send"],
    "fields": [
        ["key": "type", "type": "text", "label": "Type"],
        ["key": "company", "type": "text", "label": "Company", "show": [["field": "type", "eq": "business"]]],
        [
            "key": "people", "type": "group", "label": "People",
            "fields": [
                ["key": "guest", "type": "text", "label": "Guest"],
                ["key": "vegan", "type": "checkbox", "label": "Vegan"],
                ["key": "meal", "type": "text", "label": "Meal", "show": [["field": "vegan", "eq": false]]],
                ["key": "note", "type": "text", "label": "Meal [{{meal}}]"],
            ],
        ],
        ["key": "summary", "type": "text", "label": "Company [{{company}}]"],
    ],
]

@Suite("Recall with kept hidden values")
struct KeptRecallTests {
    @Test("an item field hidden in its item recalls nothing while its value is kept")
    @MainActor func itemField() throws {
        let values: JSONObject = ["type": "business", "company": "Acme", "people": [["guest": "Bo", "vegan": false, "meal": "Soup"]]]
        let engine = FormEngine(
            definition: try FormDefinition(json: guests), values: values,
            options: FormEngineOptions(onWarning: { _ in }, hiddenValues: .keep))
        let item = RecallOptions(item: RecallItem(group: "people", index: 0))
        #expect(engine.recallText("Meal [{{meal}}]", options: item) == "Meal [Soup]")
        #expect(engine.recallText("Company [{{company}}]") == "Company [Acme]")
        engine.setItemValue("people", 0, "vegan", true)
        engine.setValue("type", "personal")
        #expect(engine.values["people"] == [["guest": "Bo", "vegan": true, "meal": "Soup"]])
        #expect(engine.values["company"] == "Acme")
        #expect(engine.recallText("Meal [{{meal}}]", options: item) == "Meal []")
        #expect(engine.recallText("Company [{{company}}]") == "Company []")
    }
}
