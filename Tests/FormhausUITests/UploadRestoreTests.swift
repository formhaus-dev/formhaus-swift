import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore
@testable import FormhausUI

private let files: JSONValue = [
    "id": "files", "title": "Files", "submit": ["label": "Send"],
    "fields": .array(["kept", "gone", "lookalike", "lookalikeGone"].map { ["key": .string($0), "type": "file", "label": "F"] }),
]

enum ConstructionPath: String, CaseIterable {
    case form
    case model
    case engine
}

@MainActor
private func restoredModel(_ path: ConstructionPath, _ snapshot: FormSnapshot) throws -> FormModel {
    let definition = try FormDefinition(json: files)
    let submit: SubmitHandler = { _, _ in nil }
    switch path {
    case .form:
        let owned = OwnedForm(
            definition: definition, values: [:], engine: FormEngineOptions(), renderer: FormRendererOptions(), restoring: snapshot,
            submit: submit)
        return ModelHolder().resolve(.definition(owned))
    case .model:
        return FormModel(definition: definition, restoring: snapshot, onSubmit: submit)
    case .engine:
        return FormModel(engine: FormEngine(definition: definition, restoring: snapshot), onSubmit: submit)
    }
}

enum ForeignPath: String, CaseIterable {
    case linkedFolder
    case linkedFile
    case parentEscape
}

private func snapshot(_ value: URL) -> FormSnapshot {
    FormSnapshot(version: 1, definitionId: "files", values: ["kept": .string(value.absoluteString)], step: nil, skipped: [], seed: "")
}

@MainActor
private func restored(_ value: URL) throws -> FormModel {
    try restoredModel(.model, snapshot(value))
}

private func upload() -> URL {
    UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/cv.txt")
}

private func write(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("cv".utf8).write(to: url)
}

@Suite("Uploads on restore", .serialized)
@MainActor
struct UploadRestoreTests {
    @Test("a restored upload is adopted, a missing one is cleared and other files are left alone", arguments: ConstructionPath.allCases)
    func restore(path: ConstructionPath) throws {
        let manager = FileManager.default
        let kept = UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/cv.txt")
        let gone = UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/gone.txt")
        let base = manager.temporaryDirectory.appendingPathComponent("formhaus-lookalike-\(UUID().uuidString)")
        let lookalike = base.appendingPathComponent("formhaus-uploads/\(UUID().uuidString)/cv.txt")
        let lookalikeGone = base.appendingPathComponent("formhaus-uploads/\(UUID().uuidString)/gone.txt")
        try write(kept)
        try write(lookalike)
        defer {
            try? manager.removeItem(at: kept.deletingLastPathComponent())
            try? manager.removeItem(at: base)
        }
        let values: JSONObject = [
            "kept": .string(kept.absoluteString), "gone": .string(gone.absoluteString), "lookalike": .string(lookalike.absoluteString),
            "lookalikeGone": .string(lookalikeGone.absoluteString),
        ]
        let snapshot = FormSnapshot(version: 1, definitionId: "files", values: values, step: nil, skipped: [], seed: "")
        let form = try restoredModel(path, snapshot)
        form.start()
        #expect(form.pickedFile(forKey: "kept")?.standardizedFileURL.path == kept.standardizedFileURL.path)
        #expect(form.engine.values["gone"] == .null)
        #expect(form.engine.values["lookalike"] == values["lookalike"])
        #expect(form.engine.values["lookalikeGone"] == values["lookalikeGone"])
        #expect(form.pickedFile(forKey: "lookalike") == nil)
        UploadStore.release(owner: ObjectIdentifier(form))
        #expect(!manager.fileExists(atPath: kept.path))
        #expect(manager.fileExists(atPath: lookalike.path))
    }

    @Test("an upload in the initial values of a fresh form is not adopted")
    func freshStart() throws {
        let kept = UploadStore.directory.appendingPathComponent("\(UUID().uuidString)/cv.txt")
        try write(kept)
        defer { try? FileManager.default.removeItem(at: kept.deletingLastPathComponent()) }
        let form = FormModel(definition: try FormDefinition(json: files), initialValues: ["kept": .string(kept.absoluteString)]) { _, _ in
            nil
        }
        #expect(form.pickedFile(forKey: "kept") == nil)
        UploadStore.release(owner: ObjectIdentifier(form))
        #expect(FileManager.default.fileExists(atPath: kept.path))
    }

    @Test("a file reached through a link or a parent folder is left as given and never deleted", arguments: ForeignPath.allCases)
    func foreign(path: ForeignPath) throws {
        let manager = FileManager.default
        let outside = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = outside.appendingPathComponent("cv.txt")
        let folder = UploadStore.directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try write(target)
        try manager.createDirectory(at: UploadStore.directory, withIntermediateDirectories: true)
        defer {
            try? manager.removeItem(at: outside)
            try? manager.removeItem(at: folder)
        }
        let value: URL
        switch path {
        case .linkedFolder:
            try manager.createSymbolicLink(at: folder, withDestinationURL: outside)
            value = folder.appendingPathComponent("cv.txt")
        case .linkedFile:
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            value = folder.appendingPathComponent("cv.txt")
            try manager.createSymbolicLink(at: value, withDestinationURL: target)
        case .parentEscape:
            value = URL(fileURLWithPath: "\(folder.path)/../../\(outside.lastPathComponent)/cv.txt")
        }
        let form = try restored(value)
        #expect(form.engine.values["kept"] == .string(value.absoluteString))
        #expect(form.pickedFile(forKey: "kept") == nil)
        UploadStore.release(owner: ObjectIdentifier(form))
        #expect(manager.fileExists(atPath: target.path))
    }

    @Test("a file another live form owns stays with it, also under a lowercase folder name", arguments: [false, true])
    func ownedElsewhere(lowercase: Bool) throws {
        let kept = upload()
        try write(kept)
        defer { try? FileManager.default.removeItem(at: kept.deletingLastPathComponent()) }
        let owner = try restored(kept)
        #expect(owner.pickedFile(forKey: "kept") != nil)
        let folder = kept.deletingLastPathComponent().lastPathComponent
        let value = lowercase ? UploadStore.directory.appendingPathComponent("\(folder.lowercased())/cv.txt") : kept
        let form = try restored(value)
        #expect(form.engine.values["kept"] == .string(value.absoluteString))
        #expect(form.pickedFile(forKey: "kept") == nil)
        UploadStore.release(owner: ObjectIdentifier(form))
        #expect(FileManager.default.fileExists(atPath: kept.path))
        #expect(owner.pickedFile(forKey: "kept") != nil)
        UploadStore.release(owner: ObjectIdentifier(owner))
        #expect(!FileManager.default.fileExists(atPath: kept.path))
    }

    @Test("a form replaced by a new definition with the same id takes over the restored files")
    func replacedForm() throws {
        let kept = upload()
        try write(kept)
        defer { try? FileManager.default.removeItem(at: kept.deletingLastPathComponent()) }
        let restoring = snapshot(kept)
        var renamed = try #require(files.objectValue)
        renamed["title"] = "Documents"
        let holder = ModelHolder()
        let forms = try [files, .object(renamed)].map { json in
            holder.resolve(
                .definition(
                    OwnedForm(
                        definition: try FormDefinition(json: json), values: [:], engine: FormEngineOptions(),
                        renderer: FormRendererOptions(), restoring: restoring, submit: { _, _ in nil })))
        }
        #expect(forms[0] !== forms[1])
        UploadStore.release(owner: ObjectIdentifier(forms[0]))
        #expect(forms[1].pickedFile(forKey: "kept")?.standardizedFileURL.path == kept.standardizedFileURL.path)
        UploadStore.release(owner: ObjectIdentifier(forms[1]))
        #expect(!FileManager.default.fileExists(atPath: kept.path))
    }
}
