import Foundation
import Testing

@testable import FormhausCore
@testable import FormhausUI

private let missingFiles: [JSONValue] = ["a.pdf", "photo.png"].map {
    .string(UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/\($0)").absoluteString)
}

private let outsideFiles: [JSONValue] = [
    "file:///Users/x/a.pdf", "file:///tmp/formhaus-missing-b.png",
    .string(UploadStore.directory.absoluteString + "x/..%2F..%2Fformhaus-missing/f"),
]

@MainActor
private func requiredForm(_ value: JSONValue, log: SubmitLog) throws -> FormModel {
    let required: JSONValue = [
        "id": "attachment", "title": "Attachment", "submit": ["label": "Send"],
        "fields": [["key": "doc", "type": "file", "label": "Document", "validation": ["required": true]]],
    ]
    return FormModel(definition: try FormDefinition(json: required), initialValues: ["doc": value]) { values, _ in
        log.values.append(values)
        return nil
    }
}

@Suite("Missing files", .serialized)
@MainActor
struct MissingFileTests {
    @Test("a file value whose file is gone shows the empty state", arguments: missingFiles)
    func missingReference(value: JSONValue) throws {
        let form = try attachmentForm(["doc": value])
        form.start()
        let field = try docContext(form)
        #expect(field.fileName == nil)
        #expect(field.reference == nil)
        #expect(field.fileValueText == form.text(forLabel: "chooseFile"))
    }

    @Test("a picked file deleted from disk is no longer picked")
    func deletedPick() async throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("formhaus-cv-\(UUID().uuidString).txt")
        try Data("cv".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let form = try attachmentForm()
        form.start()
        let field = try docContext(form)
        let copy = try #require(await UploadStore.copy(source, owner: ObjectIdentifier(form)))
        field.replaceFile(with: copy)
        try FileManager.default.removeItem(at: copy)
        #expect(form.pickedFile(forKey: "doc") == nil)
        #expect(try docContext(form).fileName == nil)
        #expect(try docContext(form).reference == nil)
        UploadStore.release(owner: ObjectIdentifier(form))
    }

    @Test("a missing file is submitted as null", arguments: missingFiles)
    func missingSubmitted(value: JSONValue) async throws {
        let log = SubmitLog()
        let form = try attachmentForm(["doc": value], log: log)
        form.start()
        await form.submit()
        #expect(log.values.count == 1)
        #expect((log.values.first?["doc"] ?? .null) == .null)
    }

    @Test("a missing file of a required field reports required and is not sent", arguments: missingFiles)
    func missingRequired(value: JSONValue) async throws {
        let log = SubmitLog()
        let form = try requiredForm(value, log: log)
        form.start()
        await form.submit()
        #expect(log.values.isEmpty)
        #expect(form.engine.errors["doc"] != nil)
        #expect(form.errorText(forKey: "doc") != nil)
        #expect(form.invalidAttempts == 1)
    }

    @Test("a file value outside the uploads folder is shown and submitted unchanged", arguments: outsideFiles)
    func outsideFile(value: JSONValue) async throws {
        let log = SubmitLog()
        let form = try requiredForm(value, log: log)
        form.start()
        #expect(try docContext(form).reference == value.stringValue)
        await form.submit()
        #expect(log.values == [["doc": value]])
        #expect(form.engine.errors["doc"] == nil)
    }

    @Test("a lookalike uploads path outside the root is neither adopted nor deleted")
    func lookalike() async throws {
        let manager = FileManager.default
        let base = manager.temporaryDirectory.appendingPathComponent("formhaus-lookalike-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: base) }
        let folder = base.appendingPathComponent("Documents/x/formhaus-uploads/a", isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let secret = folder.appendingPathComponent("secret")
        try Data("s".utf8).write(to: secret)
        let form = try attachmentForm(["doc": .string(secret.absoluteString)])
        form.start()
        let owner = ObjectIdentifier(form)
        #expect(UploadStore.owned(secret.absoluteString, by: owner) == nil)
        #expect(!UploadStore.isMissing(folder.appendingPathComponent("gone").absoluteString))
        UploadStore.discard(secret, owner: owner)
        UploadStore.prune(owner: owner, keeping: [])
        UploadStore.release(owner: owner)
        #expect(manager.fileExists(atPath: secret.path))
    }

    @Test("a symlink inside the root that points outside is neither adopted nor followed")
    func symlinkOutside() async throws {
        let manager = FileManager.default
        let outside = manager.temporaryDirectory.appendingPathComponent("formhaus-outside-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: outside) }
        let secret = outside.appendingPathComponent("secret")
        try Data("s".utf8).write(to: secret)
        let log = SubmitLog()
        let form = try attachmentForm(log: log)
        form.start()
        let owner = ObjectIdentifier(form)
        let copy = try #require(await UploadStore.copy(secret, owner: owner))
        try manager.removeItem(at: copy)
        try manager.createSymbolicLink(at: copy, withDestinationURL: secret)
        let linkedFolder = UploadStore.directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createSymbolicLink(at: linkedFolder, withDestinationURL: outside)
        defer { try? manager.removeItem(at: linkedFolder) }
        let throughFolder = linkedFolder.appendingPathComponent("secret")
        form.setValue(.string(copy.absoluteString), forKey: "doc")
        #expect(UploadStore.owned(copy.absoluteString, by: owner) == nil)
        #expect(form.pickedFile(forKey: "doc") == nil)
        #expect(UploadStore.owned(throughFolder.absoluteString, by: owner) == nil)
        #expect(!UploadStore.isMissing(linkedFolder.appendingPathComponent("gone").absoluteString))
        UploadStore.discard(throughFolder, owner: owner)
        UploadStore.release(owner: owner)
        #expect(manager.fileExists(atPath: secret.path))
        #expect(!manager.fileExists(atPath: copy.deletingLastPathComponent().path))
    }
}
