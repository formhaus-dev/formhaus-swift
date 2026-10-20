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

    @Test("the server keeps an app reference as given", arguments: references)
    func server(value: JSONValue) throws {
        let result = try validateSubmission(definition, ["doc": value])
        #expect(result.values == ["doc": value])
        #expect(result.errors.isEmpty)
    }

    @Test("an app reference in the initial values is kept, submitted and not shown", arguments: references)
    func initialValues(value: JSONValue) async throws {
        let log = SubmitLog()
        let form = try model(["doc": value], log: log)
        form.start()
        #expect(form.engine.values["doc"] == value)
        #expect(form.engine.getSubmitValues() == ["doc": value])
        #expect(try picked(form) == nil)
        await form.submit()
        #expect(log.values == [["doc": value]])
    }

    @Test("setValue keeps an app reference and does not show it", arguments: references)
    func setValue(value: JSONValue) throws {
        let form = try model()
        form.start()
        form.setValue(value, forKey: "doc")
        #expect(form.engine.values["doc"] == value)
        #expect(form.engine.getSubmitValues() == ["doc": value])
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
}
