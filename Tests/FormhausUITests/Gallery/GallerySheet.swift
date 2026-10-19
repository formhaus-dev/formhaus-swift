@_spi(Renderer) import FormhausCore
import FormhausUI
import SwiftUI

enum FieldStateKind: String, CaseIterable {
    case empty
    case filled
    case error
    case disabled
    case loading
}

struct GalleryEntry {
    let name: String
    let field: JSONValue
    let value: JSONValue?
    var states: [FieldStateKind] = FieldStateKind.allCases
}

@MainActor
func stateModel(_ entry: GalleryEntry, _ state: FieldStateKind) throws -> FormModel {
    var field = entry.field.objectValue ?? [:]
    let key = field["key"]?.stringValue ?? "field"
    if state == .error {
        var validation = field["validation"]?.objectValue ?? [:]
        validation["required"] = true
        field["validation"] = .object(validation)
    }
    let definition: JSONValue = ["id": "gallery", "title": "Gallery", "submit": ["label": "Send"], "fields": [.object(field)]]
    var values: JSONObject = [:]
    if state != .empty, state != .error, let value = entry.value { values[key] = value }
    let model = FormModel(definition: try FormDefinition(json: definition), initialValues: values) { _, _ in nil }
    switch state {
    case .error: model.engine.validate()
    case .disabled: model.loading = true
    case .loading: model.engine.setFieldLoading(key, true)
    default: break
    }
    return model
}

struct GallerySheet: View {
    let title: String
    let rows: [(String, FormModel)]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(verbatim: title).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: row.0).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    FormhausFormContent(model: row.1)
                }
            }
        }
    }
}

@MainActor
func renderGallery(_ name: String, _ sheet: some View, widths: [CGFloat] = [420]) throws {
    guard let directory = galleryDirectory else { return }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var styles: [SnapshotStyle] = []
    for width in widths {
        styles.append(SnapshotStyle(appearance: .light, width: width))
        styles.append(SnapshotStyle(appearance: .dark, width: width))
    }
    styles.append(SnapshotStyle(appearance: .light, typeSize: .accessibility2, width: widths[0]))
    for style in styles {
        try renderPNG(sheet, style: style, to: directory.appendingPathComponent("\(name)-\(style.suffix).png"))
    }
}

@MainActor
func renderEntries(_ name: String, _ entries: [GalleryEntry], widths: [CGFloat] = [420]) throws {
    for entry in entries {
        let rows = try entry.states.map { state in (state.rawValue, try stateModel(entry, state)) }
        try renderGallery("\(name)-\(entry.name)", GallerySheet(title: entry.name, rows: rows), widths: widths)
    }
}
