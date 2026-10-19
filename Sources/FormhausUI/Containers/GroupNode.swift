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
        .alert(prompt, isPresented: confirmationShown, presenting: pendingIndex(state.items)) { index in
            Button(removeName(index), role: .destructive) { drop(index) }
            Button(model.label("cancel"), role: .cancel) { confirming = nil }
        } message: { index in
            Text(model.label("removeItemBody", ["item": .string(title(index))]))
        }
    }

    private var confirmationShown: Binding<Bool> {
        Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
    }

    private var prompt: String {
        let index = pendingIndex(model.group(group.key).items) ?? 0
        return model.label("removeItemPrompt", ["item": .string(title(index))])
    }

    private func pendingIndex(_ items: [GroupItem]) -> Int? {
        items.firstIndex { $0.id == confirming }
    }

    private func groupContext(_ items: [GroupItem]) -> GroupContext {
        let limits = model.engine.itemLimits(group)
        let entries = items.enumerated().map { index, item in itemContext(item, index, canRemove: items.count > limits.min) }
        return GroupContext(
            group: group, label: group.label ?? "", helperText: group.helperText, error: model.field(group.key).error, items: entries,
            canAdd: items.count < limits.max, addLabel: group.addLabel ?? model.label("addItem"), disabled: model.disabled,
            add: { model.addItem(toGroup: group.key) })
    }

    private func itemContext(_ item: GroupItem, _ index: Int, canRemove: Bool) -> GroupItemContext {
        let content = AnyView(GroupItemFields(group: group, item: item, index: index, model: model))
        let wrapped = GroupItemContext(
            id: item.id, index: index, title: title(index), canRemove: canRemove, hasContent: model.engine.itemHasContent(group.key, index),
            removeLabel: removeLabel, removeName: removeName(index), disabled: model.disabled, content: content,
            requestRemove: { ask(index) }, remove: { drop(index) })
        return wrapped
    }

    private var removeLabel: String { group.removeLabel ?? model.label("removeItem") }

    private func title(_ index: Int) -> String {
        model.itemTitle(index, inGroup: group.key)
    }

    private func removeName(_ index: Int) -> String {
        model.label("removeItemNamed", ["label": .string(removeLabel), "item": .string(title(index))])
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
