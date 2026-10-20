@_spi(Renderer) import FormhausCore
import SwiftUI

enum SystemChunk: Identifiable {
    case rows([FormField])
    case node(FormNode)

    var id: Int {
        switch self {
        case .rows(let fields): fields.first?.nodeID ?? -1
        case .node(let node): node.nodeID
        }
    }
}

func systemChunks(_ nodes: [FormNode], alone: (FormField) -> Bool) -> [SystemChunk] {
    var result: [SystemChunk] = []
    var rows: [FormField] = []
    for node in nodes {
        if let field = node.field, !field.isGroup, !alone(field) {
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

struct SystemNodes: View {
    @Environment(\.formhausComponents) private var components
    let nodes: [FormNode]
    let model: FormModel

    var body: some View {
        ForEach(systemChunks(nodes) { isSystemBlock($0, components) }) { chunk in
            switch chunk {
            case .rows(let fields):
                Section {
                    ForEach(fields, id: \.nodeID) { field in FormhausField(field, model: model) }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(fields, id: \.nodeID) { field in
                            SystemFooterError(state: model.field(field.key), model: model, labeled: fields.count > 1 && field.label != nil)
                        }
                    }
                }
                .environment(\.formhausFooterErrors, true)
            case .node(.section(let section)):
                SystemSection(section: section, model: model)
            case .node(let node):
                SystemNodeRow(node: node, matrix: false, model: model)
            }
        }
    }
}

struct SystemNodeRow: View {
    let node: FormNode
    let matrix: Bool
    let model: FormModel

    var body: some View {
        switch node {
        case .field(let field) where field.isGroup:
            GroupNode(group: field, model: model)
        case .field(let field) where matrix && field.type == "radio":
            SystemPickerRow(context: FieldContext(field: field, model: model), matrix: true)
        case .field(let field):
            FormhausField(field, model: model)
        case .section(let section):
            SystemSection(section: section, model: model)
        }
    }
}

private struct SystemFooterError: View {
    let state: FieldState
    let model: FormModel
    let labeled: Bool

    var body: some View {
        if let error = state.error, !error.isEmpty {
            SystemErrorText(text: labeled ? model.errorText(forKey: state.key) ?? error : error)
        }
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
        let nodes = section.fields.filter { $0.type != "hidden" }
        Group {
            if let custom = components.slots.section {
                custom(
                    SectionContext(
                        section: section, title: section.title ?? "", description: description,
                        content: AnyView(ForEach(nodes, id: \.nodeID) { SystemNodeRow(node: $0, matrix: section.isMatrix, model: model) })))
            } else {
                let chunks = systemChunks(nodes) { _ in false }
                if case .node? = chunks.first {
                    Section {
                    } header: {
                        header
                    } footer: {
                        footer
                    }
                }
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, chunk in
                    switch chunk {
                    case .rows(let fields):
                        Section {
                            ForEach(fields, id: \.nodeID) { SystemNodeRow(node: .field($0), matrix: section.isMatrix, model: model) }
                        } header: {
                            if index == 0 { header }
                        } footer: {
                            if index == 0 { footer }
                        }
                    case .node(let node):
                        SystemNodeRow(node: node, matrix: section.isMatrix, model: model)
                    }
                }
            }
        }
        .environment(\.formhausNested, true)
    }

    private var description: String? {
        section.description.flatMap { $0.isEmpty ? nil : $0 }
    }

    @ViewBuilder private var header: some View {
        if let title = section.title, !title.isEmpty {
            Text(title).textCase(nil).systemSecondaryText().accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var footer: some View {
        if let description { Text(description).systemSecondaryText() }
    }
}
