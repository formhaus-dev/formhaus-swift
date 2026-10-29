import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
final class FocusLog {
    var fired: [String] = []
    var bodies: [String: Int] = [:]
}

@MainActor
func focusProbes(_ log: FocusLog) -> FormComponents {
    FormComponents.standard.field("probe") { FocusProbe(context: $0, log: log) }
}

private struct FocusProbe: View {
    let context: FieldContext
    let log: FocusLog

    var body: some View {
        log.bodies[context.key, default: 0] += 1
        return Text(context.text).onFormhausFocus(context) { log.fired.append(context.key) }
    }
}

@MainActor
func settle(_ host: NSView) {
    for _ in 0..<4 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        host.layoutSubtreeIfNeeded()
        host.display()
    }
}

@MainActor
func settle(_ host: NSView, until done: () -> Bool) {
    for _ in 0..<100 where !done() { settle(host) }
}

@MainActor
func host(_ view: some View, width: CGFloat = 400, height: CGFloat = 600) -> NSHostingView<AnyView> {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: AnyView(view.frame(width: width)))
    host.frame = CGRect(x: 0, y: 0, width: width, height: height)
    settle(host)
    return host
}

private func twoSteps(required: Bool) -> JSONValue {
    let validation: JSONValue = required ? ["required": true] : [:]
    return [
        "id": "p", "title": "P", "submit": ["label": "Send"],
        "steps": [
            ["id": "one", "title": "One", "fields": [["key": "a", "type": "probe", "label": "A", "validation": validation]]],
            ["id": "two", "title": "Two", "fields": [["key": "b", "type": "probe", "label": "B"]]],
        ],
    ]
}

@Suite("Focus reaches views created later", .serialized)
@MainActor
struct FocusViewTests {
    private func probes(_ log: FocusLog) -> FormComponents {
        FormComponents.standard.field("probe") { FocusProbe(context: $0, log: log) }
    }

    @Test("an error summary link to another step focuses the field once its step renders")
    func summaryLink() async throws {
        let form = FormModel(definition: try FormDefinition(json: twoSteps(required: false))) { _, _ in nil }
        let log = FocusLog()
        let view = host(FormhausFormContent(model: form).formhausComponents(probes(log)))
        await form.next()
        settle(view)
        form.setErrors(["a": "bad"])
        form.focus(field: "a")
        settle(view)
        #expect(form.structure.currentStep?.id == "one")
        #expect(log.fired == ["a"])
        form.focus(field: "a")
        settle(view)
        #expect(log.fired == ["a", "a"])
    }

    @Test("a submit that returns to an invalid step focuses its field")
    func submitReturn() async throws {
        let form = FormModel(definition: try FormDefinition(json: twoSteps(required: true)), initialValues: ["a": "x"]) { _, _ in nil }
        let log = FocusLog()
        let view = host(FormhausFormContent(model: form).formhausComponents(probes(log)))
        await form.next()
        settle(view)
        form.setValue("", forKey: "a")
        await form.submit()
        settle(view)
        #expect(form.structure.currentStep?.id == "one")
        #expect(log.fired.last == "a")
    }

    @Test("adding a group item focuses its first field")
    func groupAdd() throws {
        let json: JSONValue = [
            "id": "g", "title": "G", "submit": ["label": "Send"],
            "fields": [["key": "team", "type": "group", "label": "Team", "fields": [["key": "name", "type": "probe", "label": "Name"]]]],
        ]
        let form = FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
        let log = FocusLog()
        let view = host(FormhausFormContent(model: form).formhausComponents(probes(log)))
        #expect(form.group("team").items.isEmpty)
        form.addItem(toGroup: "team")
        settle(view)
        #expect(form.group("team").items.count == 1)
        #expect(log.fired == ["team.0.name"])
    }

    @Test("a stale request does not fire when another field asked later")
    func staleRequest() async throws {
        let form = FormModel(definition: try FormDefinition(json: twoSteps(required: false))) { _, _ in nil }
        let log = FocusLog()
        let view = host(FormhausFormContent(model: form).formhausComponents(probes(log)))
        await form.next()
        settle(view)
        form.requestFocus("a")
        form.requestFocus("b")
        await form.back()
        settle(view)
        #expect(!log.fired.contains("a"))
    }
}
