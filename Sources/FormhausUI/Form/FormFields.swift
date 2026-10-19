@_spi(Renderer) import FormhausCore
import SwiftUI

public struct FormFields: View {
    @Environment(\.formhausTokens) private var tokens
    let model: FormModel

    public init(model: FormModel) {
        self.model = model
    }

    public var body: some View {
        let nodes = model.structure.nodes.filter { $0.type != "hidden" }
        VStack(alignment: .leading, spacing: tokens.spacing.gap) {
            ForEach(nodes, id: \.nodeID) { node in
                FormNodeView(node: node, model: model)
            }
        }
    }
}

struct FormNodeView: View {
    let node: FormNode
    let model: FormModel

    var body: some View {
        switch node {
        case .field(let field):
            FormhausField(field, model: model)
        case .section(let section):
            SectionNode(section: section, model: model)
        }
    }
}

struct SectionNode: View {
    @Environment(\.formhausTokens) private var tokens
    let section: FormSection
    let model: FormModel

    var body: some View {
        let fields = section.fields.filter { $0.type != "hidden" }
        VStack(alignment: .leading, spacing: tokens.spacing.s1) {
            Text(section.title ?? "").formhausText(.heading).accessibilityAddTraits(.isHeader)
            if let description = section.description, !description.isEmpty {
                Text(description).formhausText(.helper)
            }
            if section.isMatrix, !fields.isEmpty {
                MatrixRows(fields: fields, model: model)
                    .padding(
                        .top, section.description == nil ? tokens.spacing.s7 - tokens.spacing.s1 : tokens.spacing.s9 - tokens.spacing.s1)
            } else if !fields.isEmpty {
                VStack(alignment: .leading, spacing: tokens.spacing.gap) {
                    ForEach(fields, id: \.nodeID) { node in
                        FormNodeView(node: node, model: model)
                    }
                }
                .padding(.top, section.description == nil ? tokens.spacing.s7 - tokens.spacing.s1 : tokens.spacing.s9 - tokens.spacing.s1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .id(section.key)
    }
}
