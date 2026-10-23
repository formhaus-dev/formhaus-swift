import Testing

@_spi(Renderer) @testable import FormhausCore

@MainActor
private final class Calls {
    var sent = false
}

@Suite("Restoring a form snapshot")
@MainActor
struct SnapshotRestoreTests {
    @Test("a snapshot restored past an empty required field blocks submit and goes back to that step")
    func requiredOnEarlierStep() async throws {
        let engine = try FormEngine(
            definition: trip,
            restoring: FormSnapshot(version: 1, definitionId: "trip", values: [:], step: "seat", skipped: ["extras"], seed: ""))
        #expect(engine.currentStep?.id == "seat")
        engine.setValue("seat", "s1")
        let calls = Calls()
        let sent = try await engine.submit { _, _ in
            calls.sent = true
            return nil
        }
        #expect(!sent)
        #expect(!calls.sent)
        #expect(engine.currentStep?.id == "who")
        #expect(engine.errors["name"] != nil)
    }

    @Test("a restored skipped step gets its start values, as a live skip does")
    func skippedStepReset() async throws {
        let definition: JSONValue = [
            "id": "plan", "title": "Plan", "submit": ["label": "Send"],
            "steps": [
                [
                    "id": "choice", "title": "Choice", "skip": ["label": "Skip"],
                    "fields": [["key": "plan", "type": "text", "label": "Plan", "defaultValue": "basic"]],
                ],
                [
                    "id": "details", "title": "Details",
                    "fields": [
                        ["key": "name", "type": "text", "label": "Name"],
                        ["key": "company", "type": "text", "label": "Company", "show": [["field": "plan", "eq": "pro"]]],
                    ],
                ],
            ],
        ]
        let live = try FormEngine(definition: definition)
        live.setValue("plan", "pro")
        #expect(try await live.skip())
        let snapshot = FormSnapshot(
            version: 1, definitionId: "plan", values: ["plan": "pro", "company": "Acme", "name": "Ada"], step: "details",
            skipped: ["choice"], seed: "")
        let engine = try FormEngine(definition: definition, restoring: snapshot)
        #expect(engine.restored)
        #expect(engine.values["plan"] == "basic")
        #expect(engine.values["plan"] == live.values["plan"])
        #expect(engine.visibleFields.map(\.key) == ["name"])
        #expect(engine.visibleFields.map(\.key) == live.visibleFields.map(\.key))
        #expect(engine.values["name"] == "Ada")
        #expect(engine.isStepSkipped("choice"))
    }
}
