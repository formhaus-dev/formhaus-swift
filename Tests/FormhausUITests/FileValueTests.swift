import Foundation
import Testing

@testable import FormhausCore
@testable import FormhausUI

@MainActor
final class SubmitLog {
    var values: [JSONObject] = []
}

private let references: [JSONValue] = ["file:///Users/x/a.pdf", "upload-123", "file:///tmp/b.png", "https://cdn.example.com/cv.pdf"]

@Suite("File values", .serialized)
@MainActor
struct FileValueTests {
    private let definition: JSONValue = [
        "id": "attachment", "title": "Attachment", "submit": ["label": "Send"],
        "fields": [["key": "doc", "type": "file", "label": "Document"]],
    ]

    private func model(_ values: JSONObject = [:], log: SubmitLog = SubmitLog()) throws -> FormModel {
        FormModel(definition: try FormDefinition(json: definition), initialValues: values) { values, _ in
            log.values.append(values)
            return nil
        }
    }

    private func context(_ form: FormModel) throws -> FieldContext {
        FieldContext(field: try #require(form.engine.definition.fields?.first?.field), model: form)
    }

    private func picked(_ form: FormModel) throws -> String? {
        try context(form).fileName
    }

    @Test("an app reference in the initial values is submitted and not shown", arguments: references)
    func initialValues(value: JSONValue) async throws {
        let log = SubmitLog()
        let form = try model(["doc": value], log: log)
        form.start()
        #expect(try picked(form) == nil)
        await form.submit()
        #expect(log.values == [["doc": value]])
    }

    @Test("setValue does not show an app reference as a picked file", arguments: references)
    func setValue(value: JSONValue) throws {
        let form = try model()
        form.start()
        form.setValue(value, forKey: "doc")
        #expect(try picked(form) == nil)
        #expect(form.pickedFile(forKey: "doc") == nil)
    }

    @Test("a reference shows as plain text and can be cleared", arguments: references)
    func clearReference(value: JSONValue) throws {
        let form = try model(["doc": value])
        form.start()
        let field = try context(form)
        #expect(field.reference == value.stringValue)
        #expect(field.fileValueText == value.stringValue)
        field.setValue(.null)
        #expect(try context(form).reference == nil)
        #expect((form.engine.getSubmitValues()["doc"] ?? .null) == .null)
    }

    @Test("a picked file shows its name and is submitted")
    func pickedFile() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-cv-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let log = SubmitLog()
        let form = try model(log: log)
        form.start()
        let copy = try #require(await UploadStore.copy(source, owner: ObjectIdentifier(form)))
        form.setValue(.string(copy.absoluteString), forKey: "doc")
        #expect(try picked(form) == source.lastPathComponent)
        #expect(try context(form).reference == nil)
        #expect(form.pickedFile(forKey: "doc") == copy)
        for variant in [" \(copy.absoluteString)\n", copy.absoluteString.replacingOccurrences(of: "file:", with: "FILE:")] {
            #expect(UploadStore.owned(variant, by: ObjectIdentifier(form)) == copy)
        }
        await form.submit()
        #expect(log.values == [["doc": .string(copy.absoluteString)]])
        UploadStore.release(owner: ObjectIdentifier(form))
        #expect(try picked(form) == nil)
    }

    @Test("a file picked on one form is not an upload of another form")
    func foreignUpload() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-cv-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let first = try model()
        let second = try model()
        let copy = try #require(await UploadStore.copy(source, owner: ObjectIdentifier(first)))
        first.setValue(.string(copy.absoluteString), forKey: "doc")
        second.setValue(.string(copy.absoluteString), forKey: "doc")
        #expect(first.pickedFile(forKey: "doc") == copy)
        #expect(second.pickedFile(forKey: "doc") == nil)
        #expect(try picked(second) == nil)
        #expect(try context(second).reference == copy.absoluteString)
        UploadStore.release(owner: ObjectIdentifier(first))
    }
    private let conditional: JSONValue = [
        "id": "attachment", "title": "Attachment", "submit": ["label": "Send"],
        "fields": [
            ["key": "attach", "type": "checkbox", "label": "Attach"],
            ["key": "doc", "type": "file", "label": "Document", "show": [["field": "attach", "eq": true]]],
        ],
    ]

    private func pick(_ form: FormModel, _ source: URL) async throws -> URL {
        let field = try #require(form.engine.definition.allFields.first { $0.key == "doc" })
        let copy = try #require(await UploadStore.copy(source, owner: ObjectIdentifier(form)))
        FieldContext(field: field, model: form).replaceFile(with: copy)
        return copy
    }

    private func source() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-cv-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: url)
        return url
    }

    @Test("a picked file survives its field being hidden and shown again")
    func hiddenAndShown() async throws {
        let source = try source()
        defer { try? FileManager.default.removeItem(at: source) }
        let form = FormModel(definition: try FormDefinition(json: conditional), initialValues: ["attach": true]) { _, _ in nil }
        form.start()
        let copy = try await pick(form, source)
        form.setValue(false, forKey: "attach")
        #expect(form.engine.values["doc"] == nil)
        form.setValue(true, forKey: "attach")
        #expect(FileManager.default.fileExists(atPath: copy.path))
        #expect(form.pickedFile(forKey: "doc") == copy)
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("reset deletes the picked files")
    func resetDeletes() async throws {
        let source = try source()
        defer { try? FileManager.default.removeItem(at: source) }
        let form = try model()
        form.start()
        let copy = try await pick(form, source)
        form.engine.reset()
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(form.pickedFile(forKey: "doc") == nil)
    }

    @Test("a new definition keeps the files still in the values")
    func replaceDefinitionKeeps() async throws {
        let source = try source()
        defer { try? FileManager.default.removeItem(at: source) }
        let form = FormModel(definition: try FormDefinition(json: conditional), initialValues: ["attach": true]) { _, _ in nil }
        form.start()
        let copy = try await pick(form, source)
        form.engine.replaceDefinition(try FormDefinition(json: definition))
        #expect(form.pickedFile(forKey: "doc") == copy)
        let note: JSONValue = [
            "id": "note", "title": "Note", "submit": ["label": "Send"], "fields": [["key": "note", "type": "text", "label": "Note"]],
        ]
        form.engine.replaceDefinition(try FormDefinition(json: note))
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("picking a new file deletes the previous one")
    func pickAgain() async throws {
        let source = try source()
        defer { try? FileManager.default.removeItem(at: source) }
        let form = try model()
        form.start()
        let first = try await pick(form, source)
        let second = try await pick(form, source)
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
        #expect(form.pickedFile(forKey: "doc") == second)
        UploadStore.release(owner: ObjectIdentifier(form))
    }
}
