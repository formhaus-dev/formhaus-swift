import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

private let application: JSONValue = [
    "formatVersion": "1.5", "id": "application", "title": "Application", "submit": ["label": "Send"],
    "fields": [
        ["key": "cv", "type": "file", "label": "CV"],
        ["key": "note", "type": "text", "label": "Note", "helperText": "You attached {{cv}}"],
    ],
]

@MainActor
private func helper(_ form: FormModel) throws -> String? {
    form.texts(for: try #require(form.engine.definition.allFields.last)).helperText
}

@Suite("Recall of files", .serialized)
@MainActor
struct FileRecallTests {
    @Test("a picked file recalls its name, not its path")
    func picked() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("cv.pdf")
        try Data("cv".utf8).write(to: source)
        let form = FormModel(definition: try FormDefinition(json: application)) { _, _ in nil }
        form.start()
        let copy = try #require(await UploadStore.copy(source, owner: ObjectIdentifier(form)))
        form.setValue(.string(copy.absoluteString), forKey: "cv")
        #expect(try helper(form) == "You attached cv.pdf")
        #expect(form.engine.recallText("{{cv}}") == "cv.pdf")
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("an app reference recalls as written", arguments: ["upload-123", "file:///Users/x/cv.pdf"])
    func reference(value: String) throws {
        let form = FormModel(definition: try FormDefinition(json: application), initialValues: ["cv": .string(value)]) { _, _ in nil }
        form.start()
        #expect(try helper(form) == "You attached \(value)")
    }
}
