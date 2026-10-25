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
                    .onSubmit { context.performPrimaryAction() }
                    .accessibilityHint(Text(verbatim: context.helperText ?? ""))
                LoadingIndicator(visible: context.loading)
            }
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked)
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
        }
    }

    @ViewBuilder private var input: some View {
        if kind == .password {
            SecureField(text: binding, prompt: Text(verbatim: "")) { Text(verbatim: context.accessibilityName) }.placeholder(
                prompt, visible: binding.wrappedValue.isEmpty)
        } else {
            TextField(text: binding, prompt: Text(verbatim: "")) { Text(verbatim: context.accessibilityName) }.placeholder(
                prompt, visible: binding.wrappedValue.isEmpty)
        }
    }

    private var kind: InputKind { InputKind(context.field) }

    private var prompt: String? {
        context.placeholder ?? context.field.mask?.stringValue
    }

    private var binding: Binding<String> {
        context.field.type == "number" ? context.numberBinding(Binding(get: { draft }, set: { draft = $0 })) : context.textBinding
    }
}

extension FieldContext {
    func numberBinding(_ draft: Binding<String>) -> Binding<String> {
        let shown = {
            if !draft.wrappedValue.isEmpty, let parsed = parseNumber(draft.wrappedValue), value == .number(parsed) {
                return draft.wrappedValue
            }
            return text
        }
        return Binding(
            get: shown,
            set: { text in
                guard text != shown() || text != pendingText else { return }
                draft.wrappedValue = text
                setValue(numberValue(text))
            })
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
    @Environment(\.formhausTokens) private var tokens
    let visible: Bool

    public init(visible: Bool) {
        self.visible = visible
    }

    public var body: some View {
        if visible {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(tokens.controls.indicator / 18)
                .frame(width: tokens.controls.indicator, height: tokens.controls.indicator)
                .accessibilityHidden(true)
        }
    }
}
