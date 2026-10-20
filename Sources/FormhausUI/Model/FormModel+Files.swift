@_spi(Renderer) import FormhausCore
import Foundation

extension FormModel {
    func pruneUploads(_ values: JSONObject) {
        let files = Set(values.compactMap { $0.value.stringValue }.filter { $0.hasPrefix("file:") })
        UploadStore.prune(owner: ObjectIdentifier(self), keeping: files)
    }
}

@MainActor
func dropForeignFiles(_ engine: FormEngine) {
    let values = engine.values
    for key in fileKeys(engine.definition) where values[key].map(isForeignFile) == true { engine.setValue(key, .null) }
}

@MainActor
func withoutForeignFile(_ value: JSONValue?, forKey key: String, in definition: FormDefinition) -> JSONValue? {
    guard let value, isForeignFile(value), fileKeys(definition).contains(key) else { return value }
    return .null
}

@MainActor
private func isForeignFile(_ value: JSONValue) -> Bool {
    guard let value = value.stringValue else { return false }
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
    guard text.lowercased().hasPrefix("file:") || URL(string: text)?.isFileURL == true else { return false }
    return !(URL(string: value).map(UploadStore.owns) ?? false)
}

private func fileKeys(_ definition: FormDefinition) -> Set<String> {
    Set(fileKeys(definition.steps?.flatMap(\.fields) ?? definition.fields ?? []))
}

private func fileKeys(_ nodes: [FormNode]) -> [String] {
    nodes.flatMap { node -> [String] in
        switch node {
        case .field(let field): field.type == "file" ? [field.key] : []
        case .section(let section): fileKeys(section.fields)
        }
    }
}
