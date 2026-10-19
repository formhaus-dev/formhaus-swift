import FormhausUI
import SwiftUI

struct KilnFieldFrame<Content: View>: View {
    @Environment(\.formhausTokens) private var tokens
    let context: FieldContext
    let content: Content

    init(context: FieldContext, @ViewBuilder content: () -> Content) {
        self.context = context
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(context.label).font(KilnType.label).foregroundStyle(tokens.colors.text)
                if context.isRequired {
                    Text(context.text(forLabel: "required")).font(KilnType.note).foregroundStyle(tokens.colors.textMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(context.accessibilityName)
            .accessibilityAddTraits(.isHeader)
            if let helper = context.helperText {
                Text(helper).font(KilnType.note).foregroundStyle(tokens.colors.textMuted)
            }
            content
            if let error = context.error, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(KilnType.note.weight(.medium))
                    .foregroundStyle(tokens.colors.error)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(context.isLocked ? 0.6 : 1)
        .disabled(context.isLocked)
        .accessibilityElement(children: .contain)
        .formhausScrollAnchor(context)
    }
}

struct KilnTextField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        KilnFieldFrame(context: context) {
            TextField(text: context.textBinding, prompt: Text(context.field.placeholder ?? "").foregroundStyle(tokens.colors.control)) {
                Text(context.accessibilityName)
            }
            .font(KilnType.body)
            .foregroundStyle(tokens.colors.text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled(context.field.type == "email" || context.field.inputMode?.stringValue == "url")
            #if os(iOS)
                .textInputAutocapitalization(context.field.type == "text" && context.field.inputMode == nil ? .words : .never)
                .keyboardType(keyboard)
            #endif
            .onSubmit { context.performPrimaryAction() }
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) {
                Capsule().fill(underline).frame(height: focused ? 2 : 1.5)
            }
            .animation(tokens.quick, value: focused)
            .formhausFocus(context, $focused)
        }
    }

    private var underline: Color {
        if focused { return tokens.colors.primary }
        return context.isInvalid ? tokens.colors.error : tokens.colors.border
    }

    #if os(iOS)
        private var keyboard: UIKeyboardType {
            if context.field.type == "email" { return .emailAddress }
            return context.field.inputMode?.stringValue == "url" ? .URL : .default
        }
    #endif
}
