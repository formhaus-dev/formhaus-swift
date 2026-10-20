import Foundation
import Testing

@testable import FormhausCore
@testable import FormhausUI

@MainActor
final class SubmitLog {
    var values: [JSONObject] = []
}

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
}
