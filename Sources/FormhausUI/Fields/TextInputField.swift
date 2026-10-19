@_spi(Renderer) import FormhausCore
import SwiftUI

public struct TextInputField: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var focused: Bool
    @State private var draft = ""
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            HStack(spacing: tokens.spacing.s3) {
                input
                    .textFieldStyle(.plain)
                    .textInputTraits(kind)
                    .submitLabel(context.model.structure.isLastStep ? .done : .continue)
                    .onSubmit { context.submitPrimary() }
                    .accessibilityHint(context.helperText ?? "")
                LoadingIndicator(visible: context.loading)
            }
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
            .disabled(context.isLocked)
            .fieldFocus(context, $focused)
        }
    }

    @ViewBuilder private var input: some View {
        if kind == .password {
            SecureField(text: binding, prompt: Text(verbatim: "")) { Text(context.label) }.placeholder(
                prompt, visible: binding.wrappedValue.isEmpty)
        } else {
            TextField(text: binding, prompt: Text(verbatim: "")) { Text(context.label) }.placeholder(
                prompt, visible: binding.wrappedValue.isEmpty)
        }
    }

    private var kind: InputKind { InputKind(context.field) }

    private var prompt: String? {
        context.field.placeholder ?? context.field.mask?.stringValue
    }

    private var binding: Binding<String> {
        guard context.field.type == "number" else { return context.textBinding }
        return Binding(
            get: { numberText },
            set: { text in
                draft = text
                context.setValue(numberValue(text))
            }
        )
    }

    private var numberText: String {
        if !draft.isEmpty, let parsed = parseNumber(draft), context.value == .number(parsed) { return draft }
        return context.text
    }
}

func parseNumber(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    guard let number = Double(normalized), number.isFinite else { return nil }
    return number
}

func numberValue(_ text: String) -> JSONValue? {
    if text.isEmpty { return .null }
    return parseNumber(text).map(JSONValue.number) ?? .string(text)
}

public struct LoadingIndicator: View {
    let visible: Bool

    public init(visible: Bool) {
        self.visible = visible
    }

    public var body: some View {
        if visible {
            ProgressView().controlSize(.small).accessibilityHidden(true)
        }
    }
}
