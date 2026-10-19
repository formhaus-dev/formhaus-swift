import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let composed: JSONValue = [
    "id": "c", "title": "C", "submit": ["label": "Send"],
    "fields": [
        [
            "key": "team", "type": "section", "title": "Team",
            "fields": [
                ["key": "lead", "type": "text", "label": "Lead"],
                [
                    "key": "people", "type": "group", "label": "People", "defaultItems": 1, "minItems": 1,
                    "fields": [["key": "name", "type": "text", "label": "Name", "validation": ["required": true]]],
                ],
            ],
        ]
    ],
]

@MainActor
private func render(_ components: FormComponents) throws -> FormModel {
    _ = NSApplication.shared
    let model = FormModel(definition: try FormDefinition(json: composed)) { _, _ in .ok }
    let host = NSHostingView(rootView: NavigationStack { FormhausFormContent(model: model) }.formhausComponents(components))
    host.frame = CGRect(x: 0, y: 0, width: 520, height: 1200)
    for _ in 0..<4 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
    }
    return model
}

@Suite("System set composition", .serialized)
@MainActor
struct SystemCompositionTests {
    @Test("a group inside a section renders its items as fields")
    func groupInSection() throws {
        let log = SlotLog()
        _ = try render(.system.field("text") { context in Text(context.label).onAppear { log.names.insert(context.key) } })
        #expect(log.names.contains("lead"))
        #expect(log.names.contains("people.0.name"))
    }

    @Test("registered section and group builders replace the native containers")
    func overrides() throws {
        let log = SlotLog()
        let components = FormComponents.system
            .section { context in
                Section(context.title) { context.content }.onAppear { log.names.insert("section:\(context.section.key)") }
            }
            .group { context in Text(context.label).onAppear { log.names.insert("group:\(context.group.key)") } }
        _ = try render(components)
        #expect(log.names.contains("section:team"))
        #expect(log.names.contains("group:people"))
    }
}
