import Foundation
import Testing

@testable import FormhausCore
@testable import FormhausUI

@MainActor
final class SubmitLog {
    var values: [JSONObject] = []
}

@MainActor
final class SeenValues {
    var seen: [JSONObject] = []
    var leaked: Bool { seen.contains { $0.values.contains { $0.stringValue?.contains("id_rsa") == true } } }
}

private let foreign: JSONValue = "file:///Users/x/.ssh/id_rsa"

@Suite("File values", .serialized)
@MainActor
struct FileValueTests {
    private func definition(_ defaultValue: JSONValue? = nil) throws -> FormDefinition {
        var file: JSONObject = ["key": "cv", "type": "file", "label": "CV"]
        if let defaultValue { file["defaultValue"] = defaultValue }
        return try FormDefinition(json: [
            "id": "f", "title": "F", "submit": ["label": "Send"],
            "fields": [.object(file), ["key": "note", "type": "text", "label": "Note"]],
        ])
    }

    private func model(_ definition: FormDefinition, _ values: JSONObject = [:], log: SubmitLog = SubmitLog()) -> FormModel {
        FormModel(definition: definition, initialValues: values) { values, _ in
            log.values.append(values)
            return nil
        }
    }

    @Test("local files from the definition or initial values are dropped on load")
    func dropsOnLoad() throws {
        #expect(model(try definition("file:///Users/x/.ssh/id_rsa")).engine.values["cv"]?.stringValue == nil)
        for value in ["FILE:///etc/passwd", " file:///etc/hosts", "file:/etc/hosts", "\(UploadStore.directory.absoluteString)x/cv.pdf"] {
            let form = model(try definition(), ["cv": .string(value), "note": "file:///kept"])
            #expect(form.engine.values["cv"]?.stringValue == nil)
            #expect(form.engine.values["note"] == "file:///kept")
        }
    }

    @Test("remote references and upload ids are kept", arguments: ["https://cdn.example.com/cv.pdf", "upl_123"])
    func keepsRemote(value: String) throws {
        #expect(model(try definition(.string(value))).engine.values["cv"] == .string(value))
    }

    @Test("a local file set after load is dropped on submit, an owned upload is sent")
    func dropsOnSubmit() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-cv-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let log = SubmitLog()
        let form = model(try definition(), log: log)
        form.start()
        form.setValue(.string(source.absoluteString), forKey: "cv")
        await form.submit()
        #expect(log.values.count == 1)
        #expect(log.values.last?["cv"]?.stringValue == nil)
        let copy = try #require(await UploadStore.copy(source, owner: ObjectIdentifier(form)))
        form.setValue(.string(copy.absoluteString), forKey: "cv")
        await form.submit()
        #expect(log.values.count == 2)
        #expect(log.values.last?["cv"] == .string(copy.absoluteString))
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("no hook, callback or getter sees a foreign file")
    func neverSeen() async throws {
        let seen = SeenValues()
        let definition = try FormDefinition(json: [
            "id": "f", "title": "F", "submit": ["label": "Send"],
            "steps": [
                ["id": "a", "fields": [["key": "cv", "type": "file", "label": "CV", "defaultValue": foreign]]],
                ["id": "b", "fields": [["key": "note", "type": "text", "label": "Note"]]],
            ],
        ])
        let record: @MainActor @Sendable (JSONObject) -> Bool? = { values in
            seen.seen.append(values)
            return nil
        }
        let engineOptions = FormEngineOptions(
            onBeforeStepChange: { record($0.values) }, onAfterStepChange: { _ = record($0.values) }, onBeforeSubmit: { record($0) },
            onStepValidate: {
                _ = record($1)
                return nil
            })
        let options = FormRendererOptions(
            onFieldChange: { _, value, values in seen.seen.append(values.merging(["value": value ?? .null])) },
            onValuesChange: { seen.seen.append($0) })
        let submit: SubmitHandler = { values, _ in
            seen.seen.append(values)
            return nil
        }
        let form = FormModel(
            definition: definition, initialValues: ["cv": foreign], engineOptions: engineOptions, options: options, onSubmit: submit)
        form.start()
        form.setValue(foreign, forKey: "cv")
        seen.seen.append(form.engine.getSubmitValues())
        await form.next()
        await form.back()
        form.engine.setValue("cv", foreign)
        seen.seen.append(form.engine.values)
        form.engine.reset()
        seen.seen.append(form.engine.values)
        await form.next()
        await form.submit()
        #expect(seen.seen.count > 8)
        #expect(!seen.leaked)
    }
}
