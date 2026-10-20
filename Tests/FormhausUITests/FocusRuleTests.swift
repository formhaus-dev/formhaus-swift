import AppKit
@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

private let pair: JSONValue = [
    "id": "p", "title": "P", "submit": ["label": "Send"],
    "steps": [
        [
            "id": "one", "title": "One",
            "fields": [
                ["key": "a", "type": "probe", "label": "A", "validation": ["required": true]],
                ["key": "b", "type": "probe", "label": "B", "validation": ["required": true]],
            ],
        ],
        ["id": "two", "title": "Two", "fields": [["key": "c", "type": "probe", "label": "C"]]],
    ],
]

@Suite("Focus after errors", .serialized)
@MainActor
struct FocusRuleTests {
    private func form(_ values: JSONObject = [:]) throws -> FormModel {
        FormModel(definition: try FormDefinition(json: pair), initialValues: values) { _, _ in nil }
    }

    private func render(_ form: FormModel, summary: Bool = true) -> (FocusLog, NSView) {
        let log = FocusLog()
        let behavior = FormBehavior(errorSummary: summary)
        return (log, host(FormhausFormContent(model: form).formhausComponents(focusProbes(log)).formhausBehavior(behavior)))
    }

    @Test("the error summary is on by default")
    func defaultOn() {
        #expect(FormBehavior().errorSummary)
    }

    @Test("two or more errors move focus to the summary, not to a field")
    func severalErrors() async throws {
        let model = try form()
        let (log, view) = render(model)
        await model.next()
        settle(view)
        #expect(model.focusRequest?.summary == true)
        #expect(log.fired.isEmpty)
        let trigger = ScrollTrigger(model)
        #expect(ScrollTarget.resolve(from: ScrollTrigger(try form()), to: trigger, mode: .screenTop) == .summary)
        #expect(ScrollTarget.resolve(from: ScrollTrigger(try form()), to: trigger, mode: .screenTop, summary: false) == .field("a"))
    }

    @Test("one error moves focus to its field")
    func oneError() async throws {
        let model = try form(["a": "x"])
        let (log, view) = render(model)
        await model.next()
        settle(view)
        #expect(model.focusRequest?.summary == false)
        #expect(log.fired == ["b"])
    }

    @Test("with the summary off, focus moves to the first invalid field")
    func summaryOff() async throws {
        let model = try form()
        let (log, view) = render(model, summary: false)
        await model.next()
        settle(view)
        #expect(log.fired == ["a"])
    }

    @Test("server errors on another step follow the same rule")
    func serverErrors() async throws {
        let model = try form(["a": "x", "b": "y"])
        let (log, view) = render(model)
        await model.next()
        settle(view)
        model.setErrors(["a": "Taken", "b": "Taken"])
        settle(view)
        #expect(model.structure.currentStep?.id == "one")
        #expect(model.focusRequest?.summary == true)
        #expect(log.fired.isEmpty)
        model.focus(field: "b")
        settle(view)
        #expect(log.fired == ["b"])
    }

    @Test("goToStep opens a reachable step and reports a blocked one")
    func goToStep() throws {
        let model = try form()
        model.start()
        let blocked = model.goToStep("two")
        #expect(blocked.stepId == "one" && blocked.reason == .blocked)
        model.setValue("x", forKey: "a")
        model.setValue("y", forKey: "b")
        #expect(model.goToStep("two").reached)
        #expect(model.structure.currentStep?.id == "two")
    }
}
