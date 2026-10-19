@_spi(Renderer) import FormhausCore
import SwiftUI

private struct Chunk: Identifiable {
    enum Kind {
        case rows([FormField], errorKey: String?)
        case node(FormNode)
    }

    let kind: Kind

    var id: Int {
        switch kind {
        case .rows(let fields, _): fields.first?.nodeID ?? -1
        case .node(let node): node.nodeID
        }
    }
}

struct SystemNodes: View {
    @Environment(\.formhausComponents) private var components
    let nodes: [FormNode]
    let model: FormModel

    var body: some View {
        ForEach(chunks) { chunk in
            switch chunk.kind {
            case .rows(let fields, let errorKey):
                Section {
                    ForEach(fields, id: \.nodeID) { field in FormhausField(field, model: model) }
                } footer: {
                    if let errorKey { SystemFooterError(state: model.field(errorKey)) }
                }
                .environment(\.formhausFooterErrors, true)
            case .node(.section(let section)):
                SystemSection(section: section, model: model)
            case .node(.field(let field)) where field.isGroup:
                GroupNode(group: field, model: model)
            case .node(.field(let field)):
                FormhausField(field, model: model)
            }
        }
    }

    private var chunks: [Chunk] {
        let invalid = Set(model.errorEntries.map(\.key))
        var result: [Chunk] = []
        var rows: [FormField] = []
        func close(_ errorKey: String?) {
            if !rows.isEmpty { result.append(Chunk(kind: .rows(rows, errorKey: errorKey))) }
            rows = []
        }
        for node in nodes {
            if let field = node.field, !field.isGroup, !isSystemBlock(field, components) {
                rows.append(field)
                if invalid.contains(field.key) { close(field.key) }
                continue
            }
            close(nil)
            result.append(Chunk(kind: .node(node)))
        }
        close(nil)
        return result
    }
}

private struct SystemFooterError: View {
    let state: FieldState

    var body: some View {
        if let error = state.error, !error.isEmpty { SystemErrorText(text: error) }
    }
}

extension EnvironmentValues {
    @Entry var formhausFooterErrors = false
}

private struct SystemSection: View {
    @Environment(\.formhausComponents) private var components
    let section: FormSection
    let model: FormModel

    var body: some View {
        let fields = section.fields.compactMap(\.field).filter { $0.type != "hidden" }
        Section {
            ForEach(fields, id: \.nodeID) { field in
                if section.isMatrix, field.type == "radio", components.fields[field.type] == nil {
                    SystemMatrixRow(field: field, model: model)
                } else {
                    FormhausField(field, model: model)
                }
            }
        } header: {
            if let title = section.title, !title.isEmpty { Text(title).textCase(nil).accessibilityAddTraits(.isHeader) }
        } footer: {
            if let description = section.description, !description.isEmpty { Text(description) }
        }
        .environment(\.formhausNested, true)
    }
}

private struct SystemMatrixRow: View {
    let field: FormField
    let model: FormModel

    var body: some View {
        SystemPickerRow(context: FieldContext(field: field, model: model), matrix: true)
    }
}
