@_spi(Renderer) import FormhausCore
import Foundation

extension FormModel {
    public func pickedFile(forKey key: String) -> URL? {
        engine.value(at: key)?.stringValue.flatMap { UploadStore.owned($0, by: ObjectIdentifier(self)) }
    }

    func pruneUploadsAfterRestart(_ values: JSONObject) {
        guard engine.restarts != lastRestarts else { return }
        lastRestarts = engine.restarts
        var files = Set<String>()
        for value in values.values { collectFiles(value, into: &files) }
        UploadStore.prune(owner: ObjectIdentifier(self), keeping: files)
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
