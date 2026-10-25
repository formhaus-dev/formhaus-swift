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
    @Environment(\.formhausBehavior) private var behavior
    let nodes: [FormNode]
    let model: FormModel

    var body: some View {
        ForEach(systemChunks(nodes) { isSystemBlock($0, components, limit: behavior.inlineChoiceLimit) }) { chunk in
            switch chunk {
            case .rows(let fields):
                Section {
                    ForEach(fields, id: \.nodeID) { field in FormhausField(field, model: model) }
                }
            case .node(.section(let section)):
                SystemSection(section: section, texts: model.texts(for: section), model: model)
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
            SystemSection(section: section, texts: model.texts(for: section), model: model)
        }
    }
}

private struct SystemSection: View {
    @Environment(\.formhausComponents) private var components
    let section: FormSection
    let texts: RecalledTexts
    let model: FormModel

    var body: some View {
        let nodes = section.fields.filter { $0.type != "hidden" }
        Group {
            if let custom = components.slots.section {
                custom(
                    SectionContext(
                        section: section, title: texts.title ?? "", description: description,
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
        texts.description.flatMap { $0.isEmpty ? nil : $0 }
    }

    @ViewBuilder private var header: some View {
        if let title = texts.title, !title.isEmpty {
            Text(verbatim: title).textCase(nil).systemSecondaryText().accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var footer: some View {
        if let description { Text(verbatim: description).systemSecondaryText() }
    }
}
