import AppKit
@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI
import Testing

@MainActor
final class BodyCounter {
    var counts: [String: Int] = [:]
}

private struct Probe: View {
    let context: FieldContext
    let counter: BodyCounter

    var body: some View {
        counter.counts[context.key, default: 0] += 1
        return Text(context.text)
    }
}

@Suite("Render granularity", .serialized)
@MainActor
struct RenderCountTests {
    @Test("a keystroke re-renders only the edited field")
    func keystroke() throws {
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
        let components = FormComponents.standard.field("probe") { Probe(context: $0, counter: counter) }
        let host = NSHostingView(rootView: FormhausFormContent(model: form).formhausComponents(components).frame(width: 400))
        host.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        settle(host)
        let start = counter.counts
        #expect(start["a"] == start["b"])
        form.update("a", "x")
        settle(host)
        #expect(counter.counts["a", default: 0] > start["a", default: 0])
        #expect(counter.counts["b"] == start["b"])
        form.update("c", "typing")
        form.update("c", "typing more")
        settle(host)
        #expect(counter.counts["b"] == start["b"])
    }

    private func settle(_ host: NSView) {
        for _ in 0..<3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            host.layoutSubtreeIfNeeded()
            host.display()
        }
    }
}
