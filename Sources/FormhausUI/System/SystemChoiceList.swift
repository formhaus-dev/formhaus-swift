@_spi(Renderer) import FormhausCore
import SwiftUI

func isInlineChoice(_ field: FormField, limit: Int) -> Bool {
    guard ["radio", "multiselect"].contains(field.type), !field.hasPictureOptions, field.optionsFrom == nil else { return false }
    return (field.options?.count ?? 0) <= limit
}

struct SystemChoiceList: View {
    @Environment(\.formhausNested) private var nested
    @AccessibilityFocusState private var spoken: Int?
    let context: FieldContext

    var body: some View {
        let selection = ChoiceSelection(context: context)
        let selected = Set(selection.values)
        SystemBlock(context: context, anchored: false, rows: true) {
            ForEach(Array(context.options.enumerated()), id: \.offset) { index, option in
                let value = option.value ?? ""
                let checked = selected.contains(value)
                let row = SystemCheckRow(
                    label: option.label ?? value, description: option.description, hint: context.hint(option.description), checked: checked
                ) {
                    selection.choose(value)
                }
                .formhausTestId(context.optionTestId(value))
                .disabled(context.isLocked || context.isDisabled(index))
                .readOnlyControl(context.readOnly)
                .accessibilityFocused($spoken, equals: index)
                if index == 0 {
                    let id = nested ? "\(context.key)/options" : context.key
                    row.scrollVisibility(id).id(id)
                        .onFormhausFocus(context) { spoken = focusedOption(context, selected) }
                        .sensoryFeedback(.selection, trigger: selected)
                } else {
                    row
                }
                if let reveal = context.openReveal(option) {
                    let id = revealRowID(context.key, option)
                    RevealBlock(reveal: reveal, model: context.model).scrollVisibility(id).id(id)
                }
            }
        }
    }
}

func focusedOption(_ context: FieldContext, _ selected: Set<String>) -> Int {
    guard context.field.type == "radio" else { return 0 }
    return context.options.firstIndex { selected.contains($0.value ?? "") } ?? 0
}

struct SystemCheckRow: View {
    @Environment(\.isEnabled) private var enabled
    let label: String
    var description: String?
    var hint: String?
    let checked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: label).foregroundStyle(enabled ? Color.primary : systemSecondary).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let description, !description.isEmpty {
                        Text(verbatim: description).font(.footnote).systemSecondaryText().multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                let mark = Image(systemName: "checkmark").fontWeight(.semibold)
                mark.hidden().overlay { Rectangle().fill(.tint).mask { mark }.opacity(checked ? 1 : 0) }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityHint(Text(verbatim: hint ?? description ?? ""))
        .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)
    }
}
