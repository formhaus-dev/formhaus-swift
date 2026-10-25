@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormFields: View {
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        NodeStack(nodes: model.structure.nodes.filter { $0.type != "hidden" }, model: model).id(model.structure.revision)
    }
}

struct FormNodeView: View {
    let node: FormNode
    let model: FormModel
    var reveals: [FieldReveal] = []

    var body: some View {
        switch node {
        case .field(let field) where field.isGroup:
            GroupNode(group: field, model: model)
        case .field(let field):
            FormhausField(field, model: model, reveals: reveals)
        case .section(let section):
            SectionNode(section: section, model: model)
        }
    }
}

struct SectionNode: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausComponents) private var components
    let section: FormSection
    let model: FormModel

    var body: some View {
        let texts = model.texts(for: section)
        let description = texts.description.flatMap { $0.isEmpty ? nil : $0 }
        Group {
            if let custom = components.slots.section {
                custom(
                    SectionContext(
                        section: section, title: texts.title ?? "", description: description,
                        content: AnyView(SectionFields(section: section, model: model))))
            } else {
                VStack(alignment: .leading, spacing: tokens.spacing.s1) {
                    Text(verbatim: texts.title ?? "").formhausText(.heading).accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    if let description {
                        Text(verbatim: description).formhausText(.helper).fixedSize(horizontal: false, vertical: true)
                    }
                    SectionFields(section: section, model: model)
                        .padding(.top, (description == nil ? tokens.spacing.s7 : tokens.spacing.s9) - tokens.spacing.s1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
            }
        }
        .id(section.key)
    }
}

struct SectionFields: View {
    let section: FormSection
    let model: FormModel

    var body: some View {
        let fields = section.fields.filter { $0.type != "hidden" }
        if section.isMatrix, !fields.isEmpty {
            MatrixRows(fields: fields, model: model)
        } else if !fields.isEmpty {
            NodeStack(nodes: fields, model: model)
        }
    }
}

struct NodeStack: View {
    @Environment(\.formhausTokens) private var tokens
    private let place = RevealPlacement()
    let nodes: [FormNode]
    let model: FormModel

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.gap) {
            let placed = place(nodes, model)
            ForEach(Array(placed.enumerated()), id: \.element.id) { index, item in
                let node = item.node
                let container = node.section != nil || node.field?.isGroup == true
                FormNodeView(node: node, model: model, reveals: item.reveals)
                    .padding(.top, container && index > 0 ? tokens.spacing.s5 : 0)
                    .padding(.bottom, container ? tokens.spacing.s5 : 0)
            }
        }
    }
}
