import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private func single(_ field: JSONValue) throws -> FormDefinition {
    try FormDefinition(json: ["id": "f", "title": "T", "submit": ["label": "Send"], "fields": [field]])
}

private struct TypeProbe: View {
    @State private var created: String
    let context: FieldContext
    let log: CallLog

    init(context: FieldContext, log: CallLog) {
        _created = State(initialValue: context.field.type)
        self.context = context
        self.log = log
    }

    var body: some View {
        log.calls.append("\(created):\(context.field.type)")
        return Text(context.label)
    }
}

@Suite("Replacing the definition", .serialized)
@MainActor
struct ReplaceDefinitionTests {
    @Test("a field of a new type at the same position gets a new control", arguments: [false, true])
    func sameLayout(system: Bool) throws {
        let log = CallLog()
        let components = (system ? FormComponents.system : .standard)
            .field("text") { TypeProbe(context: $0, log: log) }
            .field("number") { TypeProbe(context: $0, log: log) }
        let form = FormModel(definition: try single(["key": "age", "type": "text", "label": "Age"])) { _, _ in nil }
        let view = host(FormhausForm(model: form).formhausComponents(components))
        #expect(log.calls.last == "text:text")
        let before = form.structureVersion
        form.engine.replaceDefinition(try single(["key": "age", "type": "number", "label": "Age"]))
        settle(view)
        #expect(form.structureVersion == before + 1)
        #expect(form.structure.visibleFields.map(\.type) == ["number"])
        #expect(log.calls.last == "number:number")
    }

    @Test("a new options provider replaces the old one and drops its pending response")
    func providerSwap() async throws {
        let gate = Gate()
        let log = CallLog()
        let providers: [String: OptionsProvider] = [
            "citiesA": { _ in
                log.calls.append("a:started")
                await gate.wait()
                defer { log.calls.append("a:returned") }
                return [FieldOption(value: "a", label: "Amsterdam")]
            },
            "citiesB": { _ in [FieldOption(value: "b", label: "Berlin")] },
        ]
        let form = FormModel(
            definition: try single(["key": "city", "type": "select", "label": "City", "optionsFrom": "citiesA"]),
            options: FormRendererOptions(optionsProviders: providers)
        ) { _, _ in nil }
        form.start()
        #expect(await eventually { log.calls == ["a:started"] })
        form.engine.replaceDefinition(try single(["key": "city", "type": "select", "label": "City", "optionsFrom": "citiesB"]))
        #expect(await eventually { form.options(for: "city") != nil })
        #expect(form.options(for: "city")?.map(\.label) == ["Berlin"])
        gate.open()
        #expect(await eventually { log.calls.last == "a:returned" })
        #expect(form.options(for: "city")?.map(\.label) == ["Berlin"])
    }

    @Test("a field without a provider after replacement drops the loaded options")
    func providerRemoved() async throws {
        let providers: [String: OptionsProvider] = ["cities": { _ in [FieldOption(value: "b", label: "Berlin")] }]
        let form = FormModel(
            definition: try single(["key": "city", "type": "select", "label": "City", "optionsFrom": "cities"]),
            options: FormRendererOptions(optionsProviders: providers)
        ) { _, _ in nil }
        form.start()
        #expect(await eventually { form.options(for: "city") != nil })
        #expect(form.options(for: "city")?.map(\.label) == ["Berlin"])
        form.engine.replaceDefinition(
            try single(["key": "city", "type": "select", "label": "City", "options": [["value": "r", "label": "Rome"]]]))
        #expect(form.options(for: "city") == nil)
    }
}
