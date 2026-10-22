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
}
