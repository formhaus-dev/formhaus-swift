import SwiftUI

public struct ScaleField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        let scale = ScalePoints(context)
        let current = scale.selected(context.value)
        FieldShell(context, variant: .group) {
            VStack(alignment: .leading, spacing: tokens.spacing.s2) {
                ScaleGrid(spacing: tokens.spacing.s2) {
                    ForEach(scale.points, id: \.self) { point in
                        Button {
                            context.commit(.number(Double(point)))
                        } label: {
                            Text(String(point)).monospacedDigit()
                        }
                        .buttonStyle(ScaleBoxStyle(selected: current == point))
                        .accessibilityAddTraits(current == point ? .isSelected : [])
                        .accessibilityHint(scale.anchor(for: point) ?? "")
                    }
                }
                ScaleAnchors(anchors: scale.anchors)
            }
            .scaleInput(context, scale, current, $focused)
        }
    }
}

struct ScaleBoxStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        ScaleBox(configuration: configuration, selected: selected)
    }
}

private struct ScaleBox: View {
    @Environment(\.formhausTokens) private var tokens
    let configuration: ButtonStyleConfiguration
    let selected: Bool

    var body: some View {
        configuration.label
            .formhausText(.label, colored: false)
            .fontWeight(.medium)
            .foregroundStyle(selected ? tokens.colors.onPrimary : tokens.colors.text)
            .frame(maxWidth: .infinity, minHeight: tokens.controls.height)
            .selectableSurface(selected: selected, invalid: false, solid: true, rest: tokens.colors.inputBorder)
    }
}
