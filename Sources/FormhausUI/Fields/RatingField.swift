import SwiftUI

public struct RatingField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    @State private var hovered: Int?
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        let scale = ScalePoints(context)
        let current = scale.selected(context.value)
        let shown = hovered ?? current ?? 0
        let grid = StarGrid(
            count: scale.points.count, preferred: min(tokens.controls.star, tokens.controls.hitTarget * 1.4) + tokens.spacing.s1,
            minimum: tokens.controls.hitTarget, inset: tokens.spacing.s1 / 2, spacing: tokens.spacing.s2)
        FieldShell(context, variant: .group) {
            grid {
                ForEach(scale.points, id: \.self) { point in
                    Button {
                        context.commit(.number(Double(point)))
                    } label: {
                        GeometryReader { proxy in
                            Image(systemName: point <= shown ? "star.fill" : "star")
                                .font(.system(size: max(0, proxy.size.width - tokens.spacing.s1) * 0.8, weight: .regular))
                                .foregroundStyle(color(point <= shown))
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in hovered = inside ? point : (hovered == point ? nil : hovered) }
                    .accessibilityLabel(Text(verbatim: String(point)))
                    .accessibilityAddTraits(current == point ? .isSelected : [])
                    .accessibilityHint(Text(verbatim: scale.anchor(for: point) ?? ""))
                    .formhausTestId(context.optionTestId(String(point)))
                }
                ScaleAnchors(anchors: scale.anchors)
            }
            .scaleInput(context, scale, current, $focused)
        }
    }

    private func color(_ filled: Bool) -> Color {
        if filled { return hovered != nil ? tokens.colors.primaryHover : tokens.colors.primary }
        return context.isInvalid ? tokens.colors.error : tokens.colors.control
    }
}

struct StarGrid: Layout {
    let count: Int
    let preferred: CGFloat
    let minimum: CGFloat
    let inset: CGFloat
    let spacing: CGFloat

    private func grid(_ width: CGFloat?) -> (columns: Int, rows: Int, cell: CGFloat) {
        let total = max(1, count)
        guard let width, width.isFinite else { return (total, 1, preferred) }
        let room = max(0, width + inset)
        let fit = max(1, Int(room / minimum))
        let rows = (total + fit - 1) / fit
        let columns = (total + rows - 1) / rows
        return (columns, rows, min(preferred, room / CGFloat(columns)))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let (columns, rows, cell) = grid(proposal.width)
        let width = CGFloat(columns) * cell - inset
        var height = CGFloat(rows) * max(minimum, cell)
        if let anchors = anchors(subviews) {
            height += spacing + anchors.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let (columns, rows, cell) = grid(proposal.width ?? bounds.width)
        let row = max(minimum, cell)
        for index in subviews.indices.prefix(count) {
            let origin = CGPoint(
                x: bounds.minX - inset + CGFloat(index % columns) * cell, y: bounds.minY + CGFloat(index / columns) * row)
            subviews[index].place(at: origin, proposal: ProposedViewSize(width: cell, height: row))
        }
        if let anchors = anchors(subviews) {
            anchors.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(rows) * row + spacing),
                proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }

    private func anchors(_ subviews: Subviews) -> LayoutSubview? {
        subviews.count > count ? subviews[count] : nil
    }
}
