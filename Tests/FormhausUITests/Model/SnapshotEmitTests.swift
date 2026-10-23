import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

@MainActor
final class SnapshotLog {
    var snapshots: [FormSnapshot?] = []
    var calls: [String] = []

    var options: FormRendererOptions {
        FormRendererOptions(onSnapshotChange: { self.snapshots.append($0) })
    }
}

private let tour: JSONValue = [
    "id": "tour", "title": "Tour", "submit": ["label": "Book"],
    "steps": [
        ["id": "who", "title": "Who", "fields": [["key": "name", "type": "text", "label": "Name"]]],
        ["id": "extras", "title": "Extras", "skip": ["label": "Skip"], "fields": [["key": "meal", "type": "text", "label": "Meal"]]],
        ["id": "last", "title": "Last", "skip": ["label": "Skip"], "fields": [["key": "note", "type": "text", "label": "Note"]]],
    ],
]

func nextTurn() async {
    await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
}

private func snapshot(step: String, skipped: [String] = []) -> FormSnapshot {
    FormSnapshot(version: 1, definitionId: "tour", values: ["name": "Ada"], step: step, skipped: skipped, seed: "")
}

@MainActor
private func tourModel(_ log: SnapshotLog, restoring: FormSnapshot? = nil) throws -> FormModel {
    FormModel(definition: try FormDefinition(json: tour), options: log.options, restoring: restoring) { _, _ in
        log.calls.append("send")
        return nil
    }
}

@Suite("Snapshot changes", .serialized)
@MainActor
struct SnapshotEmitTests {
    @Test("restoring reports no snapshot")
    func noEmitOnRestore() async throws {
        let log = SnapshotLog()
        let form = try tourModel(log, restoring: snapshot(step: "last", skipped: ["extras"]))
        form.start()
        await nextTurn()
        #expect(form.structure.currentStep?.id == "last")
        #expect(log.snapshots.isEmpty)
    }

    @Test("a restore that resets values and drops a missing file reports no snapshot until the next change")
    func noEmitWhenRestoreChangesValues() async throws {
        let log = SnapshotLog()
        let gone = UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/gone.txt")
        var definition = try #require(tour.objectValue)
        definition["steps"] = .array(
            (definition["steps"]?.arrayValue ?? [])
                + [["id": "files", "title": "Files", "fields": [["key": "cv", "type": "file", "label": "CV"]]]])
        let restoring = FormSnapshot(
            version: 1, definitionId: "tour", values: ["name": "Ada", "meal": "fish", "cv": .string(gone.absoluteString)], step: "files",
            skipped: ["extras"], seed: "")
        let submit: SubmitHandler = { _, _ in nil }
        let form = FormModel(
            definition: try FormDefinition(json: .object(definition)), options: log.options, restoring: restoring, onSubmit: submit)
        #expect(form.engine.snapshot() != restoring)
        form.start()
        await nextTurn()
        #expect(log.snapshots.isEmpty)
        form.setValue("Ann", forKey: "name")
        await nextTurn()
        #expect(log.snapshots.count == 1)
    }

    @Test("changes in one run loop turn are reported once")
    func coalesced() async throws {
        let log = SnapshotLog()
        let form = try tourModel(log)
        form.start()
        form.setValue("A", forKey: "name")
        form.setValue("Ad", forKey: "name")
        form.setValue("Ada", forKey: "name")
        #expect(log.snapshots.isEmpty)
        await nextTurn()
        #expect(log.snapshots.map { $0?.values["name"] } == ["Ada"])
        await form.next()
        await nextTurn()
        #expect(log.snapshots.last??.step == "extras")
        await form.skip()
        await nextTurn()
        #expect(log.snapshots.last??.step == "last")
        #expect(log.snapshots.last??.skipped == ["extras"])
        let count = log.snapshots.count
        form.setValue("Ada", forKey: "name")
        await nextTurn()
        #expect(log.snapshots.count == count)
    }

    @Test("a submit clears the snapshot")
    func clearedOnSubmit() async throws {
        let log = SnapshotLog()
        let form = try tourModel(log, restoring: snapshot(step: "last"))
        form.start()
        form.setValue("window", forKey: "note")
        await form.submit()
        await nextTurn()
        #expect(log.calls == ["send"])
        #expect(log.snapshots.last == .some(nil))
    }

    @Test("a skip on the last step that submits clears the snapshot")
    func clearedOnSkipSubmit() async throws {
        let log = SnapshotLog()
        let form = try tourModel(log, restoring: snapshot(step: "last"))
        form.start()
        await form.skip()
        await nextTurn()
        #expect(log.calls == ["send"])
        #expect(log.snapshots.last == .some(nil))
    }

    @Test("an error thrown after the submit still clears the snapshot")
    func clearedOnAfterSubmitError() async throws {
        struct Failure: Error {}
        let log = SnapshotLog()
        let form = FormModel(
            definition: try FormDefinition(json: tour), engineOptions: FormEngineOptions(onAfterSubmit: { _, _ in throw Failure() }),
            options: log.options, restoring: snapshot(step: "last")
        ) { _, _ in
            log.calls.append("send")
            return nil
        }
        form.start()
        await form.submit()
        await nextTurn()
        #expect(log.calls == ["send"])
        #expect(log.snapshots.last == .some(nil))
    }

    @Test("a rejected submit keeps the snapshot")
    func keptOnRejection() async throws {
        let log = SnapshotLog()
        let form = FormModel(definition: try FormDefinition(json: tour), options: log.options, restoring: snapshot(step: "last")) { _, _ in
            .rejected(formErrors: ["Try again"])
        }
        form.start()
        await form.submit()
        await nextTurn()
        #expect(!log.snapshots.contains(nil))
    }

    @Test("tearing down a form while it sends still clears the snapshot")
    func clearedAfterTeardown() async throws {
        let log = SnapshotLog()
        let gate = Gate()
        var holder: ModelHolder? = ModelHolder()
        let submit: SubmitHandler = { _, _ in
            log.calls.append("send")
            await gate.wait()
            return nil
        }
        let engine = FormEngineOptions(onAfterSubmit: { _, _ in log.calls.append("after") })
        let form = OwnedForm(
            definition: try FormDefinition(json: tour), values: [:], engine: engine, renderer: log.options,
            restoring: snapshot(step: "last"), submit: submit)
        let model = try #require(holder?.resolve(.definition(form)))
        let pending = Task { await model.submit() }
        while log.calls.isEmpty { await Task.yield() }
        holder = nil
        await Task { @MainActor in }.value
        gate.open()
        await pending.value
        await nextTurn()
        #expect(log.calls == ["send", "after"])
        #expect(log.snapshots.last == .some(nil))
        #expect(log.snapshots.count == 1)
    }
}
