@_spi(Renderer) import FormhausCore
import SwiftUI

struct MatrixRows: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausComponents) private var components
    let fields: [FormNode]
    let model: FormModel

    var body: some View {
        let columns = fields.first?.field?.options ?? []
        ViewThatFits(in: .horizontal) {
            rows(columns, wide: true).frame(minWidth: tokens.controls.matrixWidth)
            rows(columns, wide: false)
        }
    }

    private func rows(_ columns: [FieldOption], wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if wide { MatrixHeader(columns: columns) }
            ForEach(Array(fields.enumerated()), id: \.element.nodeID) { index, node in
                if let field = node.field, isRow(field) {
                    MatrixRow(
                        context: FieldContext(field: field, key: field.key, state: model.field(field.key), model: model),
                        columns: columns, wide: wide, last: index == fields.count - 1)
                } else {
                    FormNodeView(node: node, model: model).padding(.vertical, tokens.spacing.s5)
                }
            }
        }
    }

    private func isRow(_ field: FormField) -> Bool {
        (field.type == "radio" || field.type == "multiselect") && components.fields[field.type] == nil && components.builtIns
    }
}

private struct MatrixHeader: View {
    @Environment(\.formhausTokens) private var tokens
    let columns: [FieldOption]

    var body: some View {
        MatrixLine(count: columns.count) {
            Color.clear.frame(height: 1)
            ForEach(columns, id: \.self) { option in
                Text(option.label ?? "").formhausText(.caption).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(.vertical, tokens.spacing.s3)
        .overlay(alignment: .bottom) { tokens.colors.border.frame(height: 1) }
        .accessibilityHidden(true)
    }
}

struct MatrixLine: Layout {
    let count: Int

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 560
        let frames = cells(width, subviews)
        return CGSize(width: width, height: frames.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (index, frame) in cells(bounds.width, subviews).enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY),
                proposal: ProposedViewSize(width: frame.width, height: bounds.height))
        }
    }

    private func cells(_ width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        let label = max(160, width * 1.5 / (1.5 + CGFloat(max(1, count))))
        let cell = max(0, (width - label) / CGFloat(max(1, count)))
        return subviews.indices.map { index in
            let x = index == 0 ? 0 : label + CGFloat(index - 1) * cell
            let w = index == 0 ? label : cell
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: w, height: nil))
            return CGRect(x: x, y: 0, width: w, height: size.height)
        }
    }
}
