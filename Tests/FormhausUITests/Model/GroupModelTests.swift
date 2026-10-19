@_spi(Renderer) import FormhausCore
import FormhausUI
import Testing

private let groupDefinition: JSONValue = [
    "id": "team", "title": "Team", "submit": ["label": "Send"],
    "fields": [
        ["key": "country", "type": "select", "label": "Country", "options": [["value": "de", "label": "Germany"]]],
        ["key": "city", "type": "select", "label": "City", "optionsFrom": "cities", "optionsDependsOn": ["country"]],
        [
            "key": "people", "type": "group", "label": "People", "defaultItems": 1, "validation": ["required": true],
            "fields": [["key": "name", "type": "text", "label": "Name", "validation": ["required": true]]],
        ],
    ],
]

@Suite("Groups and options")
@MainActor
struct GroupModelTests {
    @Test("item fields have their own signals")
    func itemFields() throws {
        let form = try model(groupDefinition)
        let first = form.field("people.0.name")
        let group = form.group("people")
        #expect(group.items.count == 1)
        #expect(fires({ _ = first.value }, when: { form.setValue("Ada", forKey: "people.0.name") }))
        #expect(!fires({ _ = group.items }, when: { form.setValue("Adam", forKey: "people.0.name") }))
        #expect(fires({ _ = group.items }, when: { form.addItem(toGroup: "people") }))
        #expect(group.items.count == 2)
        #expect(form.field("people.1.name").value == nil)
    }

    @Test("item errors carry the item title")
    func itemErrors() async throws {
        let form = try model(groupDefinition)
        await form.submit()
        #expect(form.errorGroups.flatMap(\.entries).map(\.label) == ["Name (People 1)"])
        #expect(form.focusRequest?.key == "people.0.name")
    }

    @Test("options providers load and reload when a dependency changes")
    func providers() async throws {
        let provider: OptionsProvider = { values in
            values["country"] == "de" ? [FieldOption(value: "ber", label: "Berlin")] : []
        }
        let form = try model(groupDefinition, options: FormRendererOptions(optionsProviders: ["cities": provider]))
        #expect(form.options(for: "city") == nil)
        form.start()
        for _ in 0..<10 where form.options(for: "city") == nil { await Task.yield() }
        #expect(form.options(for: "city") == [])
        form.setValue("de", forKey: "country")
        for _ in 0..<10 where form.options(for: "city")?.isEmpty != false { await Task.yield() }
        #expect(form.options(for: "city")?.map(\.label) == ["Berlin"])
    }
}
