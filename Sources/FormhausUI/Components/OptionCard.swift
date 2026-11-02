import SwiftUI

public struct OptionCardStyle: ButtonStyle {
    let selected: Bool
    let invalid: Bool

    public init(selected: Bool, invalid: Bool = false) {
        self.selected = selected
        self.invalid = invalid
    }

    public func makeBody(configuration: Configuration) -> some View {
        OptionCardBody(configuration: configuration, selected: selected, invalid: invalid)
    }
}

private struct OptionCardBody: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.isFocused) private var focused
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    let invalid: Bool

    var body: some View {
        configuration.label
            .padding(.vertical, tokens.spacing.s5)
            .padding(.horizontal, tokens.spacing.s6)
            .frame(maxWidth: .infinity, minHeight: tokens.controls.hitTarget, alignment: .leading)
            .selectableSurface(selected: selected, invalid: invalid, solid: false)
            .overlay(FocusRing(visible: focused, radius: tokens.radii.control, offset: 2))
            .scaleEffect(configuration.isPressed && !tokens.reduceMotion ? 0.99 : 1)
    }
}

struct SelectableSurface: ViewModifier {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.isEnabled) private var enabled
    @Environment(\.formhausReadOnly) private var readOnly
    @State private var hovered = false
    let selected: Bool
    let invalid: Bool
    let solid: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
        content
            .surface(shape, fill: fill, border: border, motion: tokens.quick)
            .contentShape(shape)
            .opacity(enabled ? 1 : 0.6)
            .onHover { hovered = $0 }
    }

    private var fill: Color {
        if selected { return solid ? tokens.colors.primary : tokens.colors.primarySoft }
        if readOnly { return solid ? tokens.colors.backgroundDisabled : tokens.colors.background }
        return hovered && enabled ? tokens.colors.backgroundHover : tokens.colors.background
    }

    private var border: Color {
        if selected { return tokens.colors.primary }
        if invalid { return tokens.colors.error }
        return hovered && enabled && !readOnly ? tokens.colors.inputBorderHover : tokens.colors.inputBorder
    }
}

extension View {
    func selectableSurface(selected: Bool, invalid: Bool, solid: Bool) -> some View {
        modifier(SelectableSurface(selected: selected, invalid: invalid, solid: solid))
    }
}

public struct OptionRow: View {
    @Environment(\.formhausTokens) private var tokens
    let shape: IndicatorShape
    let label: String
    let description: String?
    let selected: Bool
    let invalid: Bool

    public init(_ shape: IndicatorShape, label: String, description: String? = nil, selected: Bool, invalid: Bool = false) {
        self.shape = shape
        self.label = label
        self.description = description
        self.selected = selected
        self.invalid = invalid
    }

    public var body: some View {
        let offset = tokens.typography.body * 0.36
        HStack(alignment: .firstTextBaseline, spacing: tokens.spacing.s5) {
            ChoiceIndicator(shape, selected: selected, invalid: invalid)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + offset }
            VStack(alignment: .leading, spacing: tokens.spacing.s1) {
                Text(verbatim: label).formhausText(.option).fixedSize(horizontal: false, vertical: true)
                if let description, !description.isEmpty {
                    Text(verbatim: description).formhausText(.helper).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
