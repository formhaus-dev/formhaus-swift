import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
@Observable
final class TabChoice {
    var tab = 0
}

@MainActor
final class ModelLog {
    var model: FormModel?
    var calls: [String] = []
}

private struct ModelProbe: View {
    let context: FieldContext
    let log: ModelLog

    var body: some View {
        log.model = context.model
        return Text(context.text)
    }
}

private struct Tabs: View {
    @Bindable var choice: TabChoice
    let definition: FormDefinition
    let components: FormComponents
    let submit: SubmitHandler

    var body: some View {
        TabView(selection: $choice.tab) {
            FormhausForm(definition: definition, onSubmit: submit).formhausComponents(components).tag(0).tabItem { Text(verbatim: "Form") }
            Text(verbatim: "Other").tag(1).tabItem { Text(verbatim: "Other") }
        }
    }
}

@Suite("Leaving and returning to a form", .serialized)
@MainActor
struct DisappearTests {
    @Test("a submit keeps running when the form disappears and comes back")
    func tabSwitch() async throws {
        let log = ModelLog()
        let choice = TabChoice()
        let definition = try FormDefinition(json: [
            "id": "p", "title": "P", "submit": ["label": "Send"], "fields": [["key": "a", "type": "probe", "label": "A"]],
        ])
        let components = FormComponents.standard.field("probe") { ModelProbe(context: $0, log: log) }
        let submit: SubmitHandler = { _, _ in
            try? await Task.sleep(for: .milliseconds(300))
            log.calls.append("done")
            return .rejected(errors: ["a": "Taken"])
        }
        let view = host(Tabs(choice: choice, definition: definition, components: components, submit: submit).frame(height: 600))
        let model = try #require(log.model)
        let task = Task { await model.submit() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.submitting)
        choice.tab = 1
        settle(view)
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.submitting)
        choice.tab = 0
        settle(view)
        await task.value
        #expect(log.calls == ["done"])
        #expect(model.field("a").error == "Taken")
        #expect(log.model === model)
    }

    @Test("a focus request for a hidden field does not fire after the user moves on")
    func staleHidden() throws {
        let log = FocusLog()
        let json: JSONValue = [
            "id": "p", "title": "P", "submit": ["label": "Send"],
            "fields": [
                ["key": "a", "type": "probe", "label": "A"],
                ["key": "b", "type": "probe", "label": "B", "show": [["field": "a", "eq": "x"]]],
            ],
        ]
        let form = FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
        let view = host(FormhausFormContent(model: form).formhausComponents(focusProbes(log)))
        form.focus(field: "b")
        settle(view)
        form.setValue("x", forKey: "a")
        settle(view)
        #expect(log.fired.isEmpty)
    }
}
