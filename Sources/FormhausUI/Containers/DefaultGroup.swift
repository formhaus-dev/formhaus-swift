@_spi(Renderer) import FormhausCore
import SwiftUI

struct DefaultGroup: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.formhausComponents) private var components
    @FocusState private var focused: Bool
    let context: GroupContext
    let state: FieldState

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.s1) {
            FieldLabel(text: context.label, required: context.group.isRequired, requiredLabel: context.model.text(forLabel: "required"))
                .accessibilityAddTraits(.isHeader)
            if let helper = context.helperText, !helper.isEmpty {
                Text(helper).formhausText(.helper).fixedSize(horizontal: false, vertical: true)
            }
            if let error = context.error, !error.isEmpty { FieldError(text: error) }
            VStack(alignment: .leading, spacing: tokens.spacing.s7) {
                ForEach(context.items) { item in
                    if let custom = components.slots.groupItem { custom(item) } else { DefaultGroupItem(context: item) }
                }
                if context.canAdd {
                    Button(action: context.add) {
                        Label {
                            Text(context.addLabel)
                        } icon: {
                            Image(systemName: "plus").fontWeight(.semibold)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(FormButtonStyle(.secondary))
                    .disabled(context.disabled)
                    .focused($focused)
                    .onFormhausFocus(state, model: context.model, disabled: context.disabled) { focused = true }
                }
            }
            .padding(.top, tokens.spacing.s7 - tokens.spacing.s1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .id(context.group.key)
    }
}

struct DefaultGroupItem: View {
    @Environment(\.formhausTokens) private var tokens
    @FocusState private var removeFocused: Bool
    let context: GroupItemContext

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radii.control, style: .continuous)
        VStack(alignment: .leading, spacing: tokens.spacing.s7) {
            HStack(alignment: .center, spacing: tokens.spacing.s3) {
                Text(context.title).formhausText(.itemTitle).accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if context.canRemove {
                    Button(context.removeLabel, action: context.requestRemove)
                        .buttonStyle(FormButtonStyle(.danger, compact: true))
                        .disabled(context.disabled)
                        .accessibilityLabel(context.removeName)
                        .focused($removeFocused)
                        .onFormhausFocus(context.removeFocus, model: context.model, disabled: context.disabled) { removeFocused = true }
                        .padding(.trailing, -tokens.spacing.s4)
                }
            }
            .frame(minHeight: 32)
            context.content
        }
        .padding(.top, tokens.spacing.s7)
        .padding([.horizontal, .bottom], tokens.spacing.cardPadding)
        .overlay(shape.strokeBorder(tokens.colors.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.title)
    }
}
