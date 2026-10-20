@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemTextRow: View {
    @FocusState private var focused: Bool
    @State private var draft = ""
    let context: FieldContext
    var suggests = false

    var body: some View {
        SystemRow(context: context) {
            LabeledContent {
                HStack(spacing: 8) {
                    input
                        .labelsHidden()
                        .accessibilityLabel(Text(verbatim: context.accessibilityName))
                        .multilineTextAlignment(.trailing)
                        .textInputTraits(kind)
                        .submitLabel(nextKey != nil ? .next : context.model.structure.isLastStep ? .done : .continue)
                        .onSubmit {
                            if let nextKey { context.model.focus(field: nextKey) } else { context.performPrimaryAction() }
                        }
                        .formhausFocus(context, $focused)
                        .accessibilityHint(Text(verbatim: context.helperText ?? ""))
                    if context.loading { ProgressView().controlSize(.small) }
                }
            } label: {
                SystemRowLabel(context: context).accessibilityHidden(true)
            }
            if suggests, focused { suggestions }
        }
    }

    @ViewBuilder private var input: some View {
        let prompt = Text(verbatim: context.prompt)
        if kind == .password {
            SecureField(text: binding, prompt: prompt) { Text(verbatim: context.accessibilityName) }
        } else {
            TextField(text: binding, prompt: prompt) { Text(verbatim: context.accessibilityName) }
        }
    }

    @ViewBuilder private var suggestions: some View {
        let query = context.text.trimmingCharacters(in: .whitespaces)
        let matches = query.isEmpty ? [] : context.options.filter { ($0.label ?? $0.value ?? "").localizedCaseInsensitiveContains(query) }
        ForEach(Array(matches.prefix(5).enumerated()), id: \.offset) { _, option in
            if option.value != context.text {
                Button(option.label ?? option.value ?? "") { context.setValue(.string(option.value ?? "")) }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
    }

    private var kind: InputKind { InputKind(context.field) }

    private var nextKey: String? {
        guard !context.isItem else { return nil }
        let types: Set = ["text", "email", "phone", "number", "password", "autocomplete"]
        let keys = context.model.structure.visibleFields.filter { types.contains($0.type) }.map(\.key)
        guard let index = keys.firstIndex(of: context.key), index + 1 < keys.count else { return nil }
        return keys[index + 1]
    }

    private var binding: Binding<String> {
        context.field.type == "number" ? context.numberBinding(Binding(get: { draft }, set: { draft = $0 })) : context.textBinding
    }
}

struct SystemTextArea: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        SystemBlock(context: context) {
            TextField(text: context.textBinding, prompt: Text(verbatim: context.prompt), axis: .vertical) {
                Text(verbatim: context.accessibilityName)
            }
            .lineLimit(rows...)
            .labelsHidden()
            .formhausFocus(context, $focused)
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
        }
    }

    private var rows: Int {
        clampedInt(context.field.rows?.numberValue, 1...40) ?? 3
    }
}

struct SystemToggleRow: View {
    @FocusState private var focused: Bool
    let context: FieldContext

    var body: some View {
        SystemRow(context: context) {
            Toggle(isOn: context.boolBinding) {
                SystemRowLabel(context: context)
            }
            .modifier(SystemToggleStyle(checkbox: context.field.type == "checkbox"))
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
            .formhausFocus(context, $focused)
        }
    }
}

private struct SystemToggleStyle: ViewModifier {
    let checkbox: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
            if checkbox { content.toggleStyle(.checkbox) } else { content.toggleStyle(.switch) }
        #else
            if checkbox { content.toggleStyle(SystemCircleCheck()) } else { content.toggleStyle(.switch) }
        #endif
    }
}

#if os(iOS)
    private struct SystemCircleCheck: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(systemSecondary))
                    configuration.label.foregroundStyle(Color.primary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
        }
    }
#endif
