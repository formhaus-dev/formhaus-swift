import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

@MainActor
final class BodyCounter {
    var counts: [String: Int] = [:]
    var helpers: [String: String] = [:]
}

private struct Probe: View {
    let context: FieldContext
    let counter: BodyCounter

    var body: some View {
        counter.counts[context.key, default: 0] += 1
        counter.helpers[context.key] = context.helperText
        return Text(verbatim: context.text)
    }
}

@Suite("Render granularity", .serialized)
@MainActor
struct RenderCountTests {
    @Test("a keystroke re-renders only the edited field", arguments: [false, true])
    func keystroke(system: Bool) throws {
        _ = NSApplication.shared
        let definition: JSONValue = [
            "id": "probe", "title": "Probe", "submit": ["label": "Send"],
            "fields": [
                ["key": "a", "type": "probe", "label": "A"], ["key": "b", "type": "probe", "label": "B"],
                ["key": "c", "type": "text", "label": "C"],
            ],
        ]
        let form = FormModel(definition: try FormDefinition(json: definition)) { _, _ in nil }
        let counter = BodyCounter()
        let components = (system ? FormComponents.system : .standard).field("probe") { Probe(context: $0, counter: counter) }
        let host = NSHostingView(rootView: FormhausFormContent(model: form).formhausComponents(components).frame(width: 400))
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        settle(host)
        let start = counter.counts
        #expect(start["a", default: 0] > 0)
        #expect(start["a"] == start["b"])
        form.setValue("x", forKey: "a")
        settle(host)
        #expect(counter.counts["a", default: 0] > start["a", default: 0])
        #expect(counter.counts["b"] == start["b"])
        form.setValue("typing", forKey: "c")
        form.setValue("typing more", forKey: "c")
        settle(host)
        #expect(counter.counts["b"] == start["b"])
    }

    @Test("a keystroke re-renders the texts that recall the field and nothing else", arguments: [false, true])
    func recallKeystroke(system: Bool) throws {
        _ = NSApplication.shared
        let definition: JSONValue = [
            "id": "probe", "title": "Probe", "formatVersion": "1.5", "submit": ["label": "Send"],
            "fields": [
                ["key": "name", "type": "probe", "label": "Name"],
                ["key": "greet", "type": "probe", "label": "Greet", "helperText": "Hi {{name}}"],
                ["key": "other", "type": "probe", "label": "Other"],
                ["key": "late", "type": "probe", "label": "Late", "helperText": "From {{other}}"],
            ],
        ]
        let form = FormModel(definition: try FormDefinition(json: definition)) { _, _ in nil }
        let counter = BodyCounter()
        let components = (system ? FormComponents.system : .standard).field("probe") { Probe(context: $0, counter: counter) }
        let host = NSHostingView(rootView: FormhausFormContent(model: form).formhausComponents(components).frame(width: 400))
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        settle(host)
        let start = counter.counts
        #expect(counter.helpers["greet"] == "Hi ")
        form.setValue("Ada", forKey: "name")
        settle(host)
        #expect(counter.helpers["greet"] == "Hi Ada")
        #expect(counter.counts["name", default: 0] > start["name", default: 0])
        #expect(counter.counts["greet", default: 0] > start["greet", default: 0])
        #expect(counter.counts["other"] == start["other"])
        #expect(counter.counts["late"] == start["late"])
        let typed = counter.counts
        form.setValue("x", forKey: "other")
        settle(host)
        #expect(counter.counts["greet"] == typed["greet"])
        #expect(counter.counts["name"] == typed["name"])
        #expect(counter.helpers["late"] == "From x")
    }

    private func settle(_ host: NSView) {
        for _ in 0..<3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            host.layoutSubtreeIfNeeded()
            host.display()
        }
    }
}
