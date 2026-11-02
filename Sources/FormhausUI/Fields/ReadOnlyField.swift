@_spi(Renderer) import FormhausCore
import SwiftUI

private let valueTypes: Set = [
    "text", "email", "phone", "number", "password", "textarea", "autocomplete", "select", "date", "time", "datetime",
]

func showsReadOnlyValue(_ context: FieldContext) -> Bool {
    context.readOnly && valueTypes.contains(context.field.type)
}

extension FieldContext {
    func readOnlyText(_ locale: Locale) -> String {
        switch field.type {
        case "password": return String(repeating: "•", count: text.count)
        case "select", "autocomplete": return options.first { $0.value == text }?.label ?? text
        case "radio", "multiselect":
            let selected = Set(ChoiceSelection.values(value, multiple: field.type == "multiselect"))
            let labels = options.filter { selected.contains($0.value ?? "") }.map { $0.label ?? $0.value ?? "" }
            return labels.formatted(.list(type: .and).locale(locale))
        case "date", "time", "datetime": return DateKind(field.type).display(text, dateStyle: .long, locale: locale) ?? text
        default: return text
        }
    }
}

struct ReadOnlyField: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.locale) private var locale
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let text = context.readOnlyText(locale)
        FieldShell(context) {
            HStack(alignment: .top, spacing: tokens.spacing.s3) {
                Text(verbatim: text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                LoadingIndicator(visible: context.loading)
            }
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: false)
            .environment(\.formhausReadOnly, true)
            .readOnlyValue(context, text, $focused)
        }
    }

    private var minHeight: CGFloat {
        guard context.field.type == "textarea" else { return 0 }
        let rows = clampedInt(context.field.rows?.numberValue, 1...40) ?? 3
        return max(tokens.controls.textareaHeight - 2 * tokens.spacing.s4 - 2, CGFloat(rows) * tokens.typography.body * 1.5)
    }
}

struct SystemReadOnlyRow: View {
    @Environment(\.locale) private var locale
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        let text = context.readOnlyText(locale)
        SystemRow(context: context) {
            LabeledContent {
                Text(verbatim: text).textSelection(.enabled).multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                SystemRowLabel(context: context)
            }
            .readOnlyValue(context, text, $focused)
        }
    }
}

struct SystemReadOnlyBlock: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        SystemBlock(context: context) {
            Text(verbatim: context.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readOnlyValue(context, context.text, $focused)
        }
    }
}

extension View {
    fileprivate func readOnlyValue(_ context: FieldContext, _ text: String, _ focused: FocusState<Bool>.Binding) -> some View {
        focusable()
            .formhausFocus(context, focused)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(Text(verbatim: text))
            .accessibilityHint(Text(verbatim: context.hintText))
            .accessibilityAddTraits(.isStaticText)
    }
}

extension EnvironmentValues {
    @Entry var formhausReadOnly = false
}

private struct ReadOnlyControl: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.formhausReadOnly, active)
            .allowsHitTesting(!active)
            .accessibilityRemoveTraits(active ? [.isButton, .isToggle] : [])
            .accessibilityAddTraits(active ? .isStaticText : [])
    }
}

private struct Adjustable: ViewModifier {
    let active: Bool
    let adjust: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if active { content.accessibilityAdjustableAction(adjust) } else { content }
    }
}

extension View {
    func readOnlyControl(_ active: Bool) -> some View {
        modifier(ReadOnlyControl(active: active))
    }

    func adjustable(unless readOnly: Bool, _ adjust: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        modifier(Adjustable(active: !readOnly, adjust: adjust))
    }
}

extension FieldContext {
    var readOnlyNote: String? { readOnly ? text(forLabel: "readOnly") : nil }

    func hint(_ parts: String?...) -> String {
        (parts + [readOnlyNote]).compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ", ")
    }
}
