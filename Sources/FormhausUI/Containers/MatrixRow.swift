@_spi(Renderer) import FormhausCore
import SwiftUI

struct MatrixRow: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    @State private var hovered = false
    let context: FieldContext
    let columns: [FieldOption]
    let wide: Bool
    let last: Bool

    var body: some View {
        Group {
            if wide {
                MatrixLine(count: columns.count) {
                    heading.padding(.vertical, tokens.spacing.s5).padding(.trailing, tokens.spacing.s5)
                    ForEach(columns, id: \.self) { option in cell(option, caption: false) }
                }
            } else {
                VStack(alignment: .leading, spacing: tokens.spacing.s3) {
                    heading.padding(.top, tokens.spacing.s5)
                    ColumnGrid(
                        columns: max(1, columns.count), minimumWidth: 60 * max(1, tokens.scale), compactWidth: 0,
                        spacing: tokens.spacing.s1,
                        fraction: 1
                    ) {
                        ForEach(columns, id: \.self) { option in cell(option, caption: true) }
                    }
                }
                .padding(.bottom, tokens.spacing.s5)
            }
        }
        .background(hovered || focused ? tokens.colors.backgroundHover : .clear)
        .overlay(alignment: .bottom) { if !last { tokens.colors.border.frame(height: 1) } }
        .onHover { hovered = $0 }
        .disabled(context.isLocked)
        .formhausFocus(context, $focused)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.accessibilityName)
        .id(context.key)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.s1) {
            (Text(context.label) + Text(context.isRequired ? " *" : "").foregroundStyle(tokens.colors.error))
                .formhausText(.option).fontWeight(.medium)
            if let helper = context.helperText { Text(helper).formhausText(.helper) }
            if let error = context.error, !error.isEmpty { FieldError(text: error) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ option: FieldOption, caption: Bool) -> some View {
        let value = option.value ?? ""
        let selected = isSelected(value)
        let invalid = context.isInvalid && !selected
        return Button {
            choose(value)
        } label: {
            VStack(spacing: tokens.spacing.s1) {
                ChoiceIndicator(context.field.type == "radio" ? .radio : .checkbox, selected: selected, invalid: invalid)
                if caption {
                    Text(option.label ?? value).formhausText(.caption).multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, caption ? tokens.spacing.s2 : 0)
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: .infinity, alignment: caption ? .top : .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label ?? value)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectedValues: [String] {
        if context.field.type == "radio" { return context.value == nil ? [] : [context.text] }
        return context.value?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private func isSelected(_ value: String) -> Bool {
        selectedValues.contains(value)
    }

    private func choose(_ value: String) {
        if context.field.type == "radio" {
            context.commit(.string(value))
            return
        }
        let current = selectedValues
        let next = current.contains(value) ? current.filter { $0 != value } : current + [value]
        context.setValue(.array(next.map(JSONValue.string)))
    }
}
