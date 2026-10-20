@_spi(Renderer) import FormhausCore
import Foundation

@MainActor
func dropForeignFiles(_ engine: FormEngine) {
    let definition = engine.definition
    let values = engine.values
    for key in Set(fileKeys(definition.steps?.flatMap(\.fields) ?? definition.fields ?? []))
    where values[key]?.stringValue.map(isForeignFile) == true {
        engine.setValue(key, .null)
    }
}

@MainActor
func isForeignFile(_ value: String) -> Bool {
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
    guard text.lowercased().hasPrefix("file:") || URL(string: text)?.isFileURL == true else { return false }
    return !(URL(string: value).map(UploadStore.owns) ?? false)
}

private func fileKeys(_ nodes: [FormNode]) -> [String] {
    nodes.flatMap { node -> [String] in
        switch node {
        case .field(let field): field.type == "file" ? [field.key] : []
        case .section(let section): fileKeys(section.fields)
        }
    }
}
