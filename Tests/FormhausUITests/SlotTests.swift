import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let slotted: JSONValue = [
    "id": "s", "title": "S", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "one", "title": "One",
            "fields": [
                ["key": "intro", "type": "section", "title": "Intro", "fields": [["key": "a", "type": "text", "label": "A"]]],
                ["key": "g", "type": "group", "label": "G", "defaultItems": 2, "fields": [["key": "n", "type": "text", "label": "N"]]],
            ],
        ],
        ["id": "two", "title": "Two", "fields": []],
    ],
]

@MainActor
final class SlotLog {
    var names: Set<String> = []
}

@Suite("Container slots", .serialized)
@MainActor
struct SlotTests {
    @Test("sections, groups, items, progress and actions use registered views")
    func slots() throws {
        _ = NSApplication.shared
        let model = FormModel(definition: try FormDefinition(json: slotted)) { _, _ in nil }
        let log = SlotLog()
        let components = slotComponents(log)
        let root = VStack {
            FormhausFormContent(model: model)
            FormErrorSummary(model: model)
            FormTopLevelErrors(model: model)
            Button("Danger") {}.buttonStyle(FormButtonStyle(.danger, busy: true, compact: true))
            Text(FormButtonVariant.text.rawValue)
        }
        let host = NSHostingView(rootView: root.formhausComponents(components).formhausBehavior(FormBehavior(stepErrorMarks: true)))
        host.frame = CGRect(x: 0, y: 0, width: 500, height: 1400)
        host.layoutSubtreeIfNeeded()
        #expect(log.names.contains("section:intro:"))
        #expect(log.names.contains("group:g:2"))
        #expect(log.names.contains("progress:1/2:Step 1 of 2:2"))
        #expect(log.names.contains("actions:Continue:false"))
    }
}

@MainActor
private func slotComponents(_ log: SlotLog) -> FormComponents {
    FormComponents.standard
        .section { context in
            VStack {
                Text(context.title)
                context.content
            }
            .onAppear { log.names.insert("section:\(context.section.key):\(context.description ?? "")") }
        }
        .group { context in
            VStack {
                Text(context.label + (context.helperText ?? "") + (context.error ?? ""))
                ForEach(context.items) { item in item.content }
                Button(context.addLabel, action: context.add).disabled(!context.canAdd || context.disabled)
            }
            .onAppear { log.names.insert("group:\(context.group.key):\(context.items.count)") }
        }
        .groupItem { item in
            HStack {
                Text(verbatim: "\(item.index) \(item.title) \(item.removeName) \(item.hasContent)")
                Button(item.removeLabel, action: item.requestRemove).disabled(!item.canRemove || item.disabled)
                Button("Drop", action: item.remove)
            }
        }
        .progress { context in
            StepProgressView(context: context).onAppear {
                log.names.insert("progress:\(context.current)/\(context.total):\(context.counterLabel):\(context.steps?.count ?? 0)")
            }
            Text(
                (context.stepTitle ?? "") + (context.stepDescription ?? "")
                    + (context.steps?.first.map { "\($0.id)\($0.errorCount)" } ?? ""))
        }
        .actions { context in
            FormActionsBar(context: context).onAppear { log.names.insert("actions:\(context.state.primaryLabel):\(context.busy)") }
            Button("Primary", action: context.performPrimaryAction)
            Button("Back", action: context.back)
            Button("Skip", action: context.skip)
            Button("Cancel", action: context.cancel)
        }
}
