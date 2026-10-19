@_spi(Renderer) import FormhausCore
import SwiftUI

private enum Chunk: Identifiable {
    case rows([FormField])
    case node(FormNode)

    var id: Int {
        switch self {
        case .rows(let fields): fields.first?.nodeID ?? -1
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
            switch chunk {
            case .rows(let fields):
                Section {
                    ForEach(fields, id: \.nodeID) { field in FormhausField(field, model: model) }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(fields, id: \.nodeID) { field in
                            SystemFooterError(state: model.field(field.key), label: fields.count > 1 ? field.label : nil)
                        }
                    }
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
        var result: [Chunk] = []
        var rows: [FormField] = []
        for node in nodes {
            if let field = node.field, !field.isGroup, !isSystemBlock(field, components) {
                rows.append(field)
                continue
            }
            if !rows.isEmpty { result.append(.rows(rows)) }
            rows = []
            result.append(.node(node))
        }
        if !rows.isEmpty { result.append(.rows(rows)) }
        return result
    }
}

private struct SystemFooterError: View {
    let state: FieldState
    let label: String?

    var body: some View {
        if let error = state.error, !error.isEmpty {
            SystemErrorText(text: label.map { summaryLine($0, error) } ?? error)
        }
    }
}

extension EnvironmentValues {
    @Entry var formhausFooterErrors = false
}

private struct SystemSection: View {
    let section: FormSection
    let model: FormModel

    var body: some View {
        let fields = section.fields.compactMap(\.field).filter { $0.type != "hidden" }
        Section {
            ForEach(fields, id: \.nodeID) { field in
                if section.isMatrix, field.type == "radio" {
                    SystemMatrixRow(field: field, model: model)
                } else {
                    FormhausField(field, model: model)
                }
            }
        } header: {
            if let title = section.title, !title.isEmpty {
                Text(title).textCase(nil).systemSecondaryText().accessibilityAddTraits(.isHeader)
            }
        } footer: {
            if let description = section.description, !description.isEmpty { Text(description).systemSecondaryText() }
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
