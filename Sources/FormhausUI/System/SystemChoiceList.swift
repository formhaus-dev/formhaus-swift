@_spi(Renderer) import FormhausCore
import SwiftUI

func isInlineChoice(_ field: FormField, limit: Int) -> Bool {
    guard ["radio", "multiselect"].contains(field.type), !field.hasPictureOptions, field.optionsFrom == nil else { return false }
    return (field.options?.count ?? 0) <= limit
}

struct SystemChoiceList: View {
    @AccessibilityFocusState private var spoken: Int?
    let context: FieldContext

    var body: some View {
        let selection = ChoiceSelection(context: context)
        let selected = Set(selection.values)
        SystemBlock(context: context, anchored: false, rows: true) {
            ForEach(Array(context.options.enumerated()), id: \.offset) { index, option in
                let value = option.value ?? ""
                let row = SystemCheckRow(label: option.label ?? value, checked: selected.contains(value)) { selection.choose(value) }
                    .formhausTestId(context.optionTestId(value))
                    .accessibilityFocused($spoken, equals: index)
                if index == 0 {
                    row.formhausScrollAnchor(context)
                        .onFormhausFocus(context) { spoken = focusedOption(context, selected) }
                        .sensoryFeedback(.selection, trigger: selected)
                } else {
                    row
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
    let label: String
    let checked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(verbatim: label).foregroundStyle(Color.primary).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint).opacity(checked ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}
