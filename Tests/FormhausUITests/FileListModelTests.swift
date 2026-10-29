import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

func receipts(_ validation: JSONObject = ["required": true]) -> JSONValue {
    [
        "formatVersion": "1.7", "id": "receipts", "title": "Receipts", "submit": ["label": "Send"],
        "fields": [["key": "docs", "type": "file", "label": "Receipts", "multiple": true, "validation": .object(validation)]],
    ]
}

@MainActor
func receiptsForm(_ values: JSONObject = [:], validation: JSONObject = ["required": true], log: SubmitLog = SubmitLog()) throws
    -> FormModel
{
    FormModel(definition: try FormDefinition(json: receipts(validation)), initialValues: values) { values, _ in
        log.values.append(values)
        return nil
    }
}

@MainActor
func pickedCopies(_ form: FormModel, _ names: [String]) async throws -> [URL] {
    var urls: [URL] = []
    for name in names {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent(name)
        try Data(name.utf8).write(to: source)
        urls.append(try #require(await UploadStore.copy(source, owner: ObjectIdentifier(form))))
    }
    return urls
}

@MainActor
func docsContext(_ form: FormModel) throws -> FieldContext {
    FieldContext(field: try #require(form.engine.definition.fields?.first?.field), model: form)
}

@Suite("File lists", .serialized)
@MainActor
struct FileListModelTests {
    @Test("picking adds files in order and submits the list")
    func add() async throws {
        let log = SubmitLog()
        let form = try receiptsForm(log: log)
        form.start()
        let first = try await pickedCopies(form, ["a.pdf"])
        let more = try await pickedCopies(form, ["b.pdf", "c.pdf"])
        try docsContext(form).receiveFiles(first)
        try docsContext(form).receiveFiles(more)
        let urls = first + more
        #expect(form.pickedFiles(forKey: "docs") == urls)
        #expect(form.pickedFile(forKey: "docs") == nil)
        #expect(try docsContext(form).fileValueText == "Files: 3")
        await form.submit()
        #expect(log.values == [["docs": .array(urls.map { .string($0.absoluteString) })]])
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("removing a file deletes its copy and moves focus to the next, previous or picker")
    func remove() async throws {
        let form = try receiptsForm(["docs": ["upload-1"]])
        form.start()
        let urls = try await pickedCopies(form, ["a.pdf", "b.pdf", "c.pdf"])
        try docsContext(form).receiveFiles(urls)
        try docsContext(form).removeFile(at: 1)
        #expect(!FileManager.default.fileExists(atPath: urls[0].path))
        #expect(form.focusRequest?.key == "docs#remove1")
        try docsContext(form).removeFile(at: 2)
        #expect(form.focusRequest?.key == "docs#remove1")
        try docsContext(form).removeFile(at: 1)
        #expect(form.focusRequest?.key == "docs#remove0")
        try docsContext(form).removeFile(at: 0)
        #expect(form.focusRequest?.key == "docs")
        #expect(form.engine.values["docs"] == [])
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("an emptied list is submitted as an empty array and fails required")
    func emptied() async throws {
        let form = try receiptsForm()
        form.start()
        try docsContext(form).receiveFiles(try await pickedCopies(form, ["a.pdf"]))
        try docsContext(form).removeFile(at: 0)
        #expect(form.engine.getSubmitValues()["docs"] == [])
        #expect(form.engine.validate()["docs"] == "This field is required")
    }

    @Test("the Remove button names the file")
    func names() throws {
        let form = try receiptsForm()
        let field = try docsContext(form)
        #expect(field.removeFileLabel == "Remove")
        #expect(field.removeFileName("a.pdf") == "Remove a.pdf")
        #expect(field.fileName == nil && field.reference == nil)
        #expect(field.fileValueText == "Choose file")
    }

    @Test("a restored list keeps the files that still exist")
    func restore() throws {
        let kept = UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/kept.pdf")
        let gone = UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/gone.pdf")
        try FileManager.default.createDirectory(at: kept.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("kept".utf8).write(to: kept)
        let values: JSONValue = ["upload-1", .string(gone.absoluteString), .string(kept.absoluteString)]
        let snapshot = FormSnapshot(version: 1, definitionId: "receipts", values: ["docs": values], step: nil, skipped: [], seed: "")
        let form = FormModel(definition: try FormDefinition(json: receipts()), restoring: snapshot) { _, _ in nil }
        form.start()
        #expect(form.engine.values["docs"] == ["upload-1", .string(kept.absoluteString)])
        #expect(form.pickedFiles(forKey: "docs").map(\.standardizedFileURL.path) == [kept.standardizedFileURL.path])
        UploadStore.release(owner: ObjectIdentifier(form))
        #expect(!FileManager.default.fileExists(atPath: kept.path))
    }
}
