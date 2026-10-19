@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemGroup<Confirmation: ViewModifier>: View {
    @Environment(\.formhausComponents) private var components
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var addFocused: Bool
    let context: GroupContext
    let state: FieldState
    let confirmation: Confirmation

    var body: some View {
        ForEach(context.items) { item in
            Section {
                if let custom = components.slots.groupItem {
                    custom(item)
                } else {
                    SystemGroupItemTitle(item: item)
                    ForEach(item.fields.filter { $0.type != "hidden" }, id: \.nodeID) { field in
                        FormhausField(field, key: "\(context.group.key).\(item.index).\(field.key)", model: context.model)
                    }
                }
            } header: {
                if item.index == 0 { header }
            }
            .environment(\.formhausNested, true)
        }
        Section {
            if context.canAdd {
                Button(action: context.add) {
                    Label(context.addLabel, systemImage: "plus.circle.fill").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .disabled(context.disabled)
                .focused($addFocused)
                .onFormhausFocus(state, model: context.model, disabled: context.disabled) { addFocused = true }
            }
        } header: {
            if context.items.isEmpty { header }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let helper = context.helperText, !helper.isEmpty { Text(helper).systemSecondaryText() }
                if let error = context.error, !error.isEmpty { SystemErrorText(text: error) }
            }
        }
        .id(context.group.key)
        .modifier(confirmation)
    }

    private var header: some View {
        tokens.marked(context.label, required: context.group.isRequired).textCase(nil).systemSecondaryText()
            .accessibilityLabel(
                context.group.isRequired ? "\(context.label), \(context.model.text(forLabel: "required"))" : context.label)
    }
}

private struct SystemGroupItemTitle: View {
    @FocusState private var removeFocused: Bool
    let item: GroupItemContext

    var body: some View {
        HStack {
            Text(item.title).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer()
            if item.canRemove {
                Button(role: .destructive, action: item.requestRemove) {
                    Text(item.removeLabel).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(item.disabled)
                .accessibilityLabel(item.removeName)
                .focused($removeFocused)
                .onFormhausFocus(item.removeFocus, model: item.model, disabled: item.disabled) { removeFocused = true }
            }
        }
        .frame(minHeight: 44)
    }
}
