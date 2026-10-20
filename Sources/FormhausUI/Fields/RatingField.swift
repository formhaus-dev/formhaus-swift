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
        let width = min(tokens.controls.star, tokens.controls.hitTarget * 1.4) + tokens.spacing.s1
        FieldShell(context, variant: .group) {
            VStack(alignment: .leading, spacing: tokens.spacing.s2) {
                HStack(spacing: 0) {
                    ForEach(scale.points, id: \.self) { point in
                        Button {
                            context.commit(.number(Double(point)))
                        } label: {
                            Image(systemName: point <= shown ? "star.fill" : "star")
                                .font(.system(size: (width - tokens.spacing.s1) * 0.8, weight: .regular))
                                .foregroundStyle(color(point <= shown))
                                .frame(width: width, height: max(tokens.controls.hitTarget, width))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in hovered = inside ? point : (hovered == point ? nil : hovered) }
                        .accessibilityLabel(Text(verbatim: String(point)))
                        .accessibilityAddTraits(current == point ? .isSelected : [])
                        .accessibilityHint(Text(verbatim: scale.anchor(for: point) ?? ""))
                    }
                }
                .padding(.leading, -tokens.spacing.s1 / 2)
                ScaleAnchors(anchors: scale.anchors).frame(width: width * CGFloat(scale.points.count), alignment: .leading)
            }
            .scaleInput(context, scale, current, $focused)
        }
    }

    private func color(_ filled: Bool) -> Color {
        if filled { return hovered != nil ? tokens.colors.primaryHover : tokens.colors.primary }
        return tokens.colors.control
    }
}
