@_spi(Renderer) import FormhausCore
import SwiftUI

public struct SelectField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            HStack(spacing: tokens.spacing.s3) {
                Text(selectedLabel ?? context.field.placeholder ?? "")
                    .formhausText(.body, colored: false)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LoadingIndicator(visible: context.loading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: tokens.typography.small, weight: .semibold))
                    .foregroundStyle(tokens.colors.textMuted)
            }
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
            .accessibilityHidden(true)
            .overlay { menu }
        }
    }

    private var menu: some View {
        Menu {
            Picker(selection: selection) {
                ForEach(context.options, id: \.self) { option in
                    Text(option.label ?? option.value ?? "").tag(option.value ?? "")
                }
            } label: {
                Text(context.accessibilityName)
            }
            .pickerStyle(.inline)
        } label: {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(context.isLocked)
        .formhausFocus(context, $focused)
        .accessibilityLabel(context.accessibilityName)
        .accessibilityValue(selectedLabel ?? "")
        .accessibilityHint(context.helperText ?? "")
    }

    private var textColor: Color {
        if selectedLabel == nil { return tokens.colors.control }
        return context.isLocked ? tokens.colors.textMuted : tokens.colors.text
    }

    private var selectedLabel: String? {
        guard context.value != nil, !context.text.isEmpty else { return nil }
        return context.options.first { $0.value == context.text }?.label ?? context.text
    }

    private var selection: Binding<String> {
        Binding(get: { context.text }, set: { context.setValue(.string($0)) })
    }
}

public struct AutocompleteField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            VStack(alignment: .leading, spacing: tokens.spacing.s1) {
                TextField(text: context.textBinding, prompt: Text(verbatim: "")) { Text(context.accessibilityName) }
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .placeholder(context.field.placeholder, visible: context.text.isEmpty)
                    .onSubmit { context.submitPrimary() }
                    .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
                    .disabled(context.isLocked)
                    .formhausFocus(context, $focused)
                if focused, !suggestions.isEmpty {
                    SuggestionList(options: suggestions) { context.setValue(.string($0)) }
                }
            }
        }
    }

    private var suggestions: [FieldOption] {
        let query = context.text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let matches = context.options.filter { option in
            (option.label ?? "").localizedCaseInsensitiveContains(query) || (option.value ?? "").localizedCaseInsensitiveContains(query)
        }
        if matches.count == 1, matches[0].value == context.text { return [] }
        return Array(matches.prefix(6))
    }
}

private struct SuggestionList: View {
    @Environment(\.formhausTokens) private var tokens
    let options: [FieldOption]
    let pick: (String) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    pick(option.value ?? "")
                } label: {
                    Text(option.label ?? option.value ?? "")
                        .formhausText(.option)
                        .frame(maxWidth: .infinity, minHeight: tokens.controls.hitTarget, alignment: .leading)
                        .padding(.horizontal, tokens.spacing.s6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, tokens.spacing.s1)
        .background(shape.fill(tokens.colors.background))
        .overlay(shape.strokeBorder(tokens.colors.border, lineWidth: 1))
        .shadow(color: tokens.colors.shadow, radius: 8, y: 2)
    }
}
