import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
final class CallLog {
    var calls: [String] = []
}

private func definition(_ id: String, _ key: String) throws -> FormDefinition {
    try FormDefinition(json: [
        "id": .string(id), "title": "T", "submit": ["label": "Send"], "fields": [["key": .string(key), "type": "probe", "label": "X"]],
    ])
}

@MainActor
private func owned(_ id: String, _ key: String, engine: FormEngineOptions = FormEngineOptions(), submit: @escaping SubmitHandler) throws
    -> OwnedForm
{
    OwnedForm(definition: try definition(id, key), values: [:], engine: engine, renderer: FormRendererOptions(), submit: submit)
}

private struct Probe: View {
    let context: FieldContext
    let log: CallLog

    var body: some View {
        log.calls.append("body:\(context.key)")
        return Text(context.text)
    }
}

@Suite("FormhausForm owns and swaps its model", .serialized)
@MainActor
struct FormLifecycleTests {
    @Test("a new model passed to FormhausForm replaces the old one")
    func modelSwap() throws {
        let log = CallLog()
        let components = FormComponents.standard.field("probe") { Probe(context: $0, log: log) }
        let first = FormModel(definition: try definition("a", "x")) { _, _ in nil }
        let second = FormModel(definition: try definition("b", "y")) { _, _ in nil }
        let view = host(FormhausForm(model: first).formhausComponents(components).frame(height: 600))
        #expect(log.calls.contains("body:x"))
        view.rootView = AnyView(FormhausForm(model: second).formhausComponents(components).frame(width: 400, height: 600))
        settle(view)
        #expect(log.calls.contains("body:y"))
    }

    @Test("the same definition keeps the model and calls the latest submit handler")
    func latestHandler() async throws {
        let log = CallLog()
        let holder = ModelHolder()
        let first: SubmitHandler = { _, _ in
            log.calls.append("first")
            return nil
        }
        let second: SubmitHandler = { _, _ in
            log.calls.append("second")
            return nil
        }
        let before: BeforeSubmitFn = { _ in
            log.calls.append("before")
            return nil
        }
        let model = holder.resolve(.definition(try owned("a", "x", submit: first)))
        let latest = try owned("a", "x", engine: FormEngineOptions(onBeforeSubmit: before), submit: second)
        #expect(holder.resolve(.definition(latest)) === model)
        await model.submit()
        #expect(log.calls == ["before", "second"])
    }

    @Test("a new definition builds a new model and cancels the old one")
    func definitionSwap() async throws {
        let holder = ModelHolder()
        let none: SubmitHandler = { _, _ in nil }
        let first = holder.resolve(.definition(try owned("a", "x", submit: none)))
        let pending = Task { await first.submit() }
        let second = holder.resolve(.definition(try owned("b", "y", submit: none)))
        await pending.value
        #expect(first !== second)
        #expect(!first.submitting)
        #expect(!second.submitting)
    }
}
