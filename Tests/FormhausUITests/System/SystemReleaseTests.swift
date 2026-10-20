import AppKit
@_spi(Renderer) import FormhausCore
import Observation
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
@Observable
private final class SetSwitch {
    var components = FormComponents.system
}

private struct Switched: View {
    let sets: SetSwitch
    let model: FormModel

    var body: some View {
        FormhausFormContent(model: model).formhausComponents(sets.components)
    }
}

private final class Count: @unchecked Sendable {
    var value = 0
}

private let custom = FormComponents.standard.field("text") { context in Text(verbatim: context.label) }

@Suite("Leaving the system set", .serialized)
@MainActor
struct SystemReleaseTests {
    private func threeSteps() throws -> FormModel {
        let json: JSONValue = [
            "id": "s", "title": "S", "submit": ["label": "Send"],
            "steps": [
                ["id": "one", "title": "One", "fields": [["key": "a", "type": "text", "label": "A"]]],
                ["id": "two", "title": "Two", "fields": [["key": "b", "type": "text", "label": "B"]]],
                ["id": "three", "title": "Three", "fields": [["key": "c", "type": "text", "label": "C"]]],
            ],
        ]
        return FormModel(definition: try FormDefinition(json: json)) { _, _ in nil }
    }

    @Test("switching from the system set to a custom set and the standard set leaves no pushed pages")
    func release() async throws {
        let model = try threeSteps()
        let sets = SetSwitch()
        let view = host(Switched(sets: sets, model: model))
        #expect(view.window == nil)
        await model.next()
        await model.next()
        settle(view)
        #expect(model.systemStack.history.count == 3)
        sets.components = custom
        settle(view)
        #expect(model.systemStack.history.count <= 1)
        sets.components = .standard
        settle(view)
        #expect(model.systemStack.history.count <= 1)
        #expect(model.structure.currentStep?.id == "three")
        sets.components = .system
        settle(view)
        #expect(model.systemStack.history.count == 3)
    }

    @Test("a released stack posts one release for its owner")
    func notifies() async throws {
        let model = try threeSteps()
        let sets = SetSwitch()
        let view = host(Switched(sets: sets, model: model))
        await model.next()
        settle(view)
        let token = model.systemStack.token
        let released = Count()
        let observer = NotificationCenter.default.addObserver(forName: .formhausStepsReleased, object: nil, queue: nil) { note in
            if note.userInfo?["owner"] as? UUID == token { released.value += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        sets.components = custom
        settle(view)
        sets.components = .standard
        settle(view)
        #expect(released.value == 1)
    }
}
