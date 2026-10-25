@_spi(Renderer) import FormhausCore
import SwiftUI

enum SystemChunk: Identifiable {
    case rows([RevealedNode])
    case node(RevealedNode)

    var id: Int {
        switch self {
        case .rows(let rows): rows.first?.id ?? -1
        case .node(let node): node.id
        }
    }
}

func systemChunks(_ nodes: [RevealedNode], alone: (FormField) -> Bool) -> [SystemChunk] {
    var result: [SystemChunk] = []
    var rows: [RevealedNode] = []
    for node in nodes {
        if let field = node.node.field, !field.isGroup, !alone(field) {
            rows.append(node)
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
    private let place = RevealPlacement()
    let nodes: [FormNode]
    let model: FormModel

    var body: some View {
        let placed = place(nodes, model)
        ForEach(systemChunks(placed) { isSystemBlock($0, components, limit: behavior.inlineChoiceLimit) }) { chunk in
            switch chunk {
            case .rows(let rows):
                Section {
                    ForEach(rows, id: \.id) { SystemNodeRow(placed: $0, matrix: false, model: model) }
                }
            case .node(let placed):
                SystemNodeRow(placed: placed, matrix: false, model: model)
            }
        }
    }
}

struct SystemNodeRow: View {
    let placed: RevealedNode
    let matrix: Bool
    let model: FormModel

    var body: some View {
        switch placed.node {
        case .field(let field) where field.isGroup:
            GroupNode(group: field, model: model)
        case .field(let field) where matrix && field.type == "radio":
            SystemPickerRow(context: FieldContext(field: field, model: model), matrix: true)
        case .field(let field):
            FormhausField(field, model: model, reveals: placed.reveals)
        case .section(let section):
            SystemSection(section: section, texts: model.texts(for: section), model: model)
        }
    }
}

private struct SystemSection: View {
    @Environment(\.formhausComponents) private var components
    private let place = RevealPlacement()
    let section: FormSection
    let texts: RecalledTexts
    let model: FormModel

    var body: some View {
        let placed = place(section.fields.filter { $0.type != "hidden" }, model)
        Group {
            if let custom = components.slots.section {
                custom(
                    SectionContext(
                        section: section, title: texts.title ?? "", description: description,
                        content: AnyView(ForEach(placed, id: \.id) { SystemNodeRow(placed: $0, matrix: section.isMatrix, model: model) })))
            } else {
                let chunks = systemChunks(placed) { _ in false }
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
                    case .rows(let rows):
                        Section {
                            ForEach(rows, id: \.id) { SystemNodeRow(placed: $0, matrix: section.isMatrix, model: model) }
                        } header: {
                            if index == 0 { header }
                        } footer: {
                            if index == 0 { footer }
                        }
                    case .node(let placed):
                        SystemNodeRow(placed: placed, matrix: section.isMatrix, model: model)
                    }
                }
                .environment(\.formhausSectionRows, true)
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
