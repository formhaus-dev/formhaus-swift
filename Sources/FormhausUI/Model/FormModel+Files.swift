@_spi(Renderer) import FormhausCore

extension FormModel {
    func pruneUploads(_ values: JSONObject) {
        let files = Set(values.compactMap { $0.value.stringValue }.filter { $0.hasPrefix("file:") })
        UploadStore.prune(owner: ObjectIdentifier(self), keeping: files)
    }
}
