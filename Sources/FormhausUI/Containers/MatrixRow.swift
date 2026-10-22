@_spi(Renderer) import FormhausCore
import SwiftUI

struct MatrixRow: View {
    @FocusState private var focused: Bool
    let field: FormField
    let model: FormModel
    let wide: Bool
    let last: Bool

    var body: some View {
        let context = FieldContext(field: field, model: model)
        MatrixRowBody(context: context, wide: wide, last: last, focused: $focused)
    }
}

private struct MatrixRowBody: View {
    @Environment(\.formhausTokens) private var tokens
    let context: FieldContext
    let wide: Bool
    let last: Bool
    var focused: FocusState<Bool>.Binding
    @State private var hovered = false

    private var columns: [FieldOption] { context.options }

    var body: some View {
        Group {
            if wide {
                MatrixLine(count: columns.count) {
                    heading.padding(.vertical, tokens.spacing.s5).padding(.trailing, tokens.spacing.s5)
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, option in cell(option, caption: false) }
                }
            } else {
                VStack(alignment: .leading, spacing: tokens.spacing.s3) {
                    heading.padding(.top, tokens.spacing.s5)
                    ColumnGrid(
                        columns: max(1, columns.count), minimumWidth: 60 * max(1, tokens.scale), compactWidth: 0,
                        spacing: tokens.spacing.s1,
                        fraction: 1, balanced: true
                    ) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, option in cell(option, caption: true) }
                    }
                }
                .padding(.bottom, tokens.spacing.s5)
            }
        }
        .background(hovered || focused.wrappedValue ? tokens.colors.backgroundHover : .clear)
        .overlay(alignment: .bottom) { if !last { tokens.colors.border.frame(height: 1) } }
        .onHover { hovered = $0 }
        .disabled(context.isLocked)
        .formhausFocus(context, focused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: context.accessibilityName))
        .formhausTestId(context.testId)
        .id(context.key)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.s1) {
            tokens.marked(context.label, required: context.isRequired)
                .formhausText(.option).fontWeight(.medium)
            if let helper = context.helperText { Text(verbatim: helper).formhausText(.helper) }
            if let error = context.error, !error.isEmpty { FieldError(text: error) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ option: FieldOption, caption: Bool) -> some View {
        let value = option.value ?? ""
        let selected = isSelected(value)
        return Button {
            choose(value)
        } label: {
            VStack(spacing: tokens.spacing.s1) {
                ChoiceIndicator(context.field.type == "radio" ? .radio : .checkbox, selected: selected)
                if caption {
                    Text(verbatim: option.label ?? value).formhausText(.caption).multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, caption ? tokens.spacing.s2 : 0)
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: .infinity, alignment: caption ? .top : .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: option.label ?? value))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .formhausTestId(context.optionTestId(value))
    }

    private func isSelected(_ value: String) -> Bool {
        ChoiceSelection(context: context).values.contains(value)
    }

    private func choose(_ value: String) {
        ChoiceSelection(context: context).choose(value)
    }
}
