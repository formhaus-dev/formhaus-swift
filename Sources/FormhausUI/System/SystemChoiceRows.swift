@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemPickerRow: View {
    @Environment(\.locale) private var locale
    #if os(iOS)
        @Environment(\.formhausTheme) private var theme
    #endif
    @FocusState private var focused: Bool
    let context: FieldContext
    var matrix = false

    var body: some View {
        SystemRow(context: context) {
            Group {
                #if os(iOS)
                    if matrix { menu } else { link }
                #else
                    if multiple { checkboxes } else { menu }
                #endif
            }
            .accessibilityLabel(Text(verbatim: context.accessibilityName))
            .accessibilityValue(summary ?? "")
            .accessibilityHint(Text(verbatim: context.helperText ?? ""))
            .formhausFocus(context, $focused)
            .sensoryFeedback(.selection, trigger: context.value)
        }
    }

    private var multiple: Bool { context.field.type == "multiselect" }

    #if os(iOS)
        private var link: some View {
            NavigationLink {
                SystemOptionList(field: context.source, key: context.key, model: context.model)
                    .formhausTheme(theme)
                    .environment(\.locale, locale)
                    .resolveFormhausTokens()
            } label: {
                SystemValueRow(context: context, value: summary)
            }
        }
    #endif

    private var menu: some View {
        Menu {
            Picker(selection: Binding(get: { context.text }, set: { choose($0) })) {
                ForEach(Array(context.options.enumerated()), id: \.offset) { _, option in
                    Text(verbatim: option.label ?? option.value ?? "").tag(option.value ?? "")
                }
            } label: {
                Text(verbatim: context.label)
            }
            .pickerStyle(.inline)
        } label: {
            SystemValueRow(context: context, value: summary, chevrons: true)
        }
        .buttonStyle(.plain)
    }

    #if os(macOS)
        private var checkboxes: some View {
            LabeledContent {
                VStack(alignment: .leading, spacing: 6) {
                    let selected = Set(ChoiceSelection(context: context).values)
                    ForEach(Array(context.options.enumerated()), id: \.offset) { _, option in
                        let value = option.value ?? ""
                        Toggle(option.label ?? value, isOn: Binding(get: { selected.contains(value) }, set: { _ in choose(value) }))
                            .toggleStyle(.checkbox)
                    }
                }
            } label: {
                SystemRowLabel(context: context)
            }
        }
    #endif

    private var summary: String? {
        let selected = Set(ChoiceSelection(context: context).values)
        let labels = context.options.filter { selected.contains($0.value ?? "") }.map { $0.label ?? $0.value ?? "" }
        return labels.isEmpty ? nil : labels.formatted(.list(type: .and).locale(locale))
    }

    private func choose(_ value: String) {
        ChoiceSelection(context: context).choose(value)
    }
}

private struct SystemValueRow: View {
    let context: FieldContext
    let value: String?
    var chevrons = false

    var body: some View {
        HStack(spacing: 8) {
            SystemRowLabel(context: context)
            Spacer(minLength: 12)
            Text(verbatim: value ?? context.choicePrompt)
                .systemSecondaryText()
                .multilineTextAlignment(.trailing)
            if chevrons {
                Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.medium))
                    .systemSecondaryText()
            }
        }
        .contentShape(Rectangle())
    }
}

#if os(iOS)
    struct SystemOptionList: View {
        @Environment(\.dismiss) private var dismiss
        let field: FormField
        let key: String
        let model: FormModel

        var body: some View {
            let context = FieldContext(field: field, key: key, model: model)
            let selection = ChoiceSelection(context: context)
            let selected = Set(selection.values)
            Form {
                Section {
                    ForEach(Array(context.options.enumerated()), id: \.offset) { _, option in
                        let value = option.value ?? ""
                        Button {
                            selection.choose(value)
                            if !selection.multiple { dismiss() }
                        } label: {
                            HStack {
                                Text(verbatim: option.label ?? value).foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint)
                                    .opacity(selected.contains(value) ? 1 : 0)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(selected.contains(value) ? .isSelected : [])
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) { SystemNotes(context: context) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text(verbatim: context.label))
            .disabled(context.isLocked)
            .sensoryFeedback(.selection, trigger: selected)
        }
    }
#endif
