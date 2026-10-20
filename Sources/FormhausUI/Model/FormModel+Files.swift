@_spi(Renderer) import FormhausCore
import Foundation

extension FormModel {
    public func pickedFile(forKey key: String) -> URL? {
        engine.value(at: key)?.stringValue.flatMap { UploadStore.owned($0, by: ObjectIdentifier(self)) }
    }

    func pruneUploads(_ values: JSONObject) {
        let files = Set(values.compactMap { $0.value.stringValue }.filter { $0.hasPrefix("file:") })
        UploadStore.prune(owner: ObjectIdentifier(self), keeping: files)
    }
}
