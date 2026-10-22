@_spi(Renderer) import FormhausCore
import Testing

@MainActor
private final class Warnings {
    var issues: [DefinitionIssue] = []
}

@Suite("Missing translations")
struct MissingTextTests {
    @Test("missingKeys lists the built-in keys a catalog lacks")
    func missingKeyList() {
        let found = missingKeys(messages: .catalog(["required": "Pflichtfeld", "email": ""]), labels: .catalog(["continue": "Weiter"]))
        #expect(!found.messages.contains(.required))
        #expect(found.messages.contains(.email))
        #expect(found.messages.contains(.minLength))
        #expect(!found.labels.contains("continue"))
        #expect(found.labels.contains("back"))
        let none = missingKeys(messages: .function { _, _, _ in nil })
        #expect(none.messages.isEmpty && none.labels.isEmpty)
    }

    @Test("a shown message and label absent from the catalogs warn once per key")
    @MainActor func warnings() throws {
        let warnings = Warnings()
        let definition = try FormDefinition(json: [
            "id": "w", "title": "W", "submit": ["label": "Send"],
            "fields": [["key": "at", "type": "time", "label": "At"], ["key": "name", "type": "text", "label": "Name"]],
        ])
        let options = FormEngineOptions(
            onWarning: { warnings.issues.append($0) }, messages: .catalog(["required": "Pflichtfeld"]))
        let engine = FormEngine(definition: definition, values: ["at": "late"], options: options)
        engine.validate()
        engine.validate()
        _ = engine.label("missingTextProbe", .catalog(["continue": "Weiter"]))
        _ = engine.label("missingTextProbe", .catalog(["continue": "Weiter"]))
        _ = engine.label("continue", .catalog(["continue": "Weiter"]))
        _ = engine.label("missingTextProbe", nil)
        let reported = warnings.issues.map { "\($0.code.rawValue) \($0.message)" }
        #expect(
            reported == [
                "missing-message-key /: The messages catalog has no \"time\" text. Add \"time\" to the messages catalog.",
                "missing-label-key /: The labels catalog has no \"missingTextProbe\" text. Add \"missingTextProbe\" to the labels catalog.",
            ])
    }
}
