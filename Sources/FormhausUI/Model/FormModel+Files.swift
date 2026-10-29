@_spi(Renderer) import FormhausCore
import Foundation

extension FormModel {
    public func pickedFile(forKey key: String) -> URL? {
        engine.value(at: key)?.stringValue.flatMap { UploadStore.owned($0, by: ObjectIdentifier(self)) }
    }

    func nameStoredFiles() {
        let owner = ObjectIdentifier(self)
        engine.storedFileName = { value in MainActor.assumeIsolated { UploadStore.owned(value, by: owner)?.lastPathComponent } }
    }

    func dropMissingFiles() {
        guard !disabled else { return }
        for field in engine.definition.allFields where field.type == "file" {
            if let kept = withoutFiles(field, engine.values[field.key], where: UploadStore.isMissing) { engine.setValue(field.key, kept) }
        }
    }

    func adoptRestoredUploads() -> Bool {
        guard engine.restored else { return false }
        let owner = ObjectIdentifier(self)
        var dropped = false
        for field in engine.definition.allFields where field.type == "file" {
            guard let kept = withoutFiles(field, engine.values[field.key], where: { !UploadStore.adopt($0, owner: owner) }) else {
                continue
            }
            engine.setValue(field.key, kept)
            dropped = true
        }
        return dropped
    }

    func pruneUploadsAfterRestart(_ values: JSONObject) {
        guard engine.restarts != lastRestarts else { return }
        lastRestarts = engine.restarts
        var files = Set<String>()
        for value in values.values { collectFiles(value, into: &files) }
        UploadStore.prune(owner: ObjectIdentifier(self), keeping: files)
    }
}

private func withoutFiles(_ field: FormField, _ value: JSONValue?, where gone: (String) -> Bool) -> JSONValue? {
    switch value {
    case .string(let text)? where gone(text):
        return .null
    case .array(let items)? where field.isFileList:
        let kept = items.filter { $0.stringValue.map(gone) != true }
        return kept.count == items.count ? nil : .array(kept)
    default:
        return nil
    }
}

private func collectFiles(_ value: JSONValue, into files: inout Set<String>) {
    switch value {
    case .string(let text) where text.hasPrefix("file:"): files.insert(text)
    case .array(let items): for item in items { collectFiles(item, into: &files) }
    case .object(let object): for item in object.values { collectFiles(item, into: &files) }
    default: break
    }
}
