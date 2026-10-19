@_spi(Renderer) import FormhausCore
import SwiftUI

struct GroupNode: View {
    @Environment(\.formhausComponents) private var components
    @Environment(\.formhausBehavior) private var behavior
    @State private var confirming: String?
    let group: FormField
    let model: FormModel

    var body: some View {
        let state = model.group(group.key)
        let context = groupContext(state.items)
        Group {
            if let custom = components.slots.group {
                custom(context)
            } else {
                DefaultGroup(context: context, state: model.field(group.key))
            }
        }
        .modifier(
            RemoveConfirmation(isPresented: confirmationShown, context: confirmContext(state.items), custom: components.slots.confirm))
    }

    private var confirmationShown: Binding<Bool> {
        Binding(
            get: { confirming != nil },
            set: { shown in
                guard !shown, let index = pendingIndex(model.group(group.key).items) else { return }
                keep(index)
            })
    }

    private func confirmContext(_ items: [GroupItem]) -> ConfirmContext? {
        guard let index = pendingIndex(items) else { return nil }
        return ConfirmContext(
            title: model.text(forLabel: "removeItemPrompt", ["item": .string(title(index))]),
            message: model.text(forLabel: "removeItemBody", ["item": .string(title(index))]), confirmLabel: removeName(index),
            cancelLabel: model.text(forLabel: "cancel"), confirm: { drop(index) }, cancel: { keep(index) })
    }

    private func pendingIndex(_ items: [GroupItem]) -> Int? {
        items.firstIndex { $0.id == confirming }
    }

    private func groupContext(_ items: [GroupItem]) -> GroupContext {
        let limits = model.engine.itemLimits(group)
        let entries = items.enumerated().map { index, item in itemContext(item, index, canRemove: items.count > limits.min) }
        return GroupContext(
            group: group, label: group.label ?? "", helperText: group.helperText, error: model.field(group.key).error, items: entries,
            canAdd: items.count < limits.max, addLabel: group.addLabel ?? model.text(forLabel: "addItem"), disabled: model.disabled,
            add: { model.addItem(toGroup: group.key) }, model: model)
    }

    private func itemContext(_ item: GroupItem, _ index: Int, canRemove: Bool) -> GroupItemContext {
        let content = AnyView(GroupItemFields(group: group, item: item, index: index, model: model))
        let wrapped = GroupItemContext(
            id: item.id, index: index, title: title(index), canRemove: canRemove,
            hasContent: model.group(group.key).hasContent.indices.contains(index) && model.group(group.key).hasContent[index],
            removeLabel: removeLabel, removeName: removeName(index), disabled: model.disabled, content: content,
            requestRemove: { ask(index) }, remove: { drop(index) }, removeFocus: model.field(removeKey(index)), model: model)
        return wrapped
    }

    private var removeLabel: String { group.removeLabel ?? model.text(forLabel: "removeItem") }

    private func title(_ index: Int) -> String {
        model.itemTitle(index, inGroup: group.key)
    }

    private func removeName(_ index: Int) -> String {
        model.text(forLabel: "removeItemNamed", ["label": .string(removeLabel), "item": .string(title(index))])
    }

    private func removeKey(_ index: Int) -> String {
        "\(group.key)#remove\(index)"
    }

    private func keep(_ index: Int) {
        confirming = nil
        model.requestFocus(removeKey(index))
    }

    private func drop(_ index: Int) {
        confirming = nil
        model.removeItem(index, fromGroup: group.key)
    }

    private func ask(_ index: Int) {
        let items = model.group(group.key).items
        guard behavior.confirmRemove, model.engine.itemHasContent(group.key, index), items.indices.contains(index) else {
            drop(index)
            return
        }
        confirming = items[index].id
    }
}

private struct GroupItemFields: View {
    @Environment(\.formhausTokens) private var tokens
    let group: FormField
    let item: GroupItem
    let index: Int
    let model: FormModel

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacing.gap) {
            ForEach(item.fields.filter { $0.type != "hidden" }, id: \.nodeID) { field in
                FormhausField(field, key: "\(group.key).\(index).\(field.key)", model: model)
            }
        }
    }
}

private struct RemoveConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let context: ConfirmContext?
    let custom: SlotBuilder<ConfirmContext>?

    func body(content: Content) -> some View {
        if let custom {
            content.sheet(isPresented: $isPresented) {
                if let context { custom(context) }
            }
        } else {
            content.alert(context?.title ?? "", isPresented: $isPresented, presenting: context) { context in
                Button(context.confirmLabel, role: .destructive, action: context.confirm)
                Button(context.cancelLabel, role: .cancel, action: context.cancel)
            } message: { context in
                Text(context.message)
            }
        }
    }
}
