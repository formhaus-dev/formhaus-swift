import FormhausCore
import Testing

@Suite("Top-level field addresses in a multi-step overlay")
struct OverlayAddressTests {
    @Test("applies fields.<key> and lets steps.<id>.fields.<key> win")
    func topLevelFields() throws {
        let definition: JSONValue = [
            "id": "trip", "title": "Trip", "submit": ["label": "Book"],
            "steps": [
                [
                    "id": "who", "title": "Who",
                    "fields": [
                        ["key": "name", "type": "text", "label": "Name", "validation": ["required": "Enter a name"]],
                        ["key": "city", "type": "select", "label": "City", "options": [["value": "rome", "label": "Rome"]]],
                    ],
                ],
                [
                    "id": "guests", "title": "Guests",
                    "fields": [
                        [
                            "key": "people", "type": "group", "label": "Guests",
                            "fields": [["key": "age", "type": "number", "label": "Age"]],
                        ]
                    ],
                ],
            ],
        ]
        let overlay: JSONValue = [
            "fields": [
                "name": ["label": "Nom", "validation": ["required": "Saisissez un nom"]],
                "city": ["label": "Ville", "options": ["rome": "Rome (Italie)"]],
                "people": ["label": "Invités", "fields": ["age": ["label": "Âge"]]],
            ],
            "steps": ["who": ["fields": ["city": ["label": "Destination"]]]],
        ]
        let steps = try #require(try localize(definition, overlay: overlay).definition.steps)
        let who = steps[0].fields.compactMap(\.field)
        #expect(who.map(\.label) == ["Nom", "Destination"])
        #expect(who[0].validation?.required == "Saisissez un nom")
        #expect(who[1].options?.first?.label == "Rome (Italie)")
        let group = try #require(steps[1].fields.first?.field)
        #expect(group.label == "Invités")
        #expect(group.items.first?.label == "Âge")
    }
}
