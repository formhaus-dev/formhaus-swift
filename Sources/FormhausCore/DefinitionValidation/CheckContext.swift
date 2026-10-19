struct FieldEntry {
    let field: FormField
    let path: String
    let step: Int
    let group: FormField?
    let parent: FormNode?
}

struct NodeEntry {
    let node: FormNode
    let path: String
    let step: Int
    let group: FormField?
    let parent: FormNode?
}

enum ConditionOwner {
    case field, step, route, action
}

struct ConditionEntry {
    let condition: ShowCondition
    let path: String
    let owner: ConditionOwner
    let step: Int
    let key: String?
    let group: String?
}

struct ScopedEntries {
    private(set) var keys: [String] = []
    private var entries = StringMap<FieldEntry>(insertionOrder: true)

    subscript(key: String) -> FieldEntry? { entries[key] }

    mutating func addFirst(_ entry: FieldEntry) {
        let key = entry.field.key
        guard entries[key] == nil else { return }
        entries[key] = entry
        keys.append(key)
    }
}

private typealias ConditionLists = [(name: String, conditions: [ShowCondition]?)]

private struct ConditionSite {
    let path: String
    let owner: ConditionOwner
    let step: Int
    var key: String?
    var group: String?

    func entries(_ lists: ConditionLists) -> [ConditionEntry] {
        lists.flatMap { name, conditions in
            (conditions ?? []).enumerated().map { index, condition in
                ConditionEntry(condition: condition, path: "\(path)/\(name)/\(index)", owner: owner, step: step, key: key, group: group)
            }
        }
    }
}

private func showLists(_ source: some Conditional) -> ConditionLists {
    [("show", source.show), ("showAny", source.showAny)]
}

private func disabledLists(_ action: FormAction?) -> ConditionLists {
    [("disabled", action?.disabled)]
}

private func nodeEntries(_ definition: FormDefinition) -> [NodeEntry] {
    var nodes: [NodeEntry] = []
    func visit(_ items: [FormNode], _ path: String, _ step: Int, _ parent: FormNode?, _ group: FormField?) {
        for (position, node) in items.enumerated() {
            let at = "\(path)/\(position)"
            nodes.append(NodeEntry(node: node, path: at, step: step, group: group, parent: parent))
            let container = node.type == "section" || node.type == "group"
            if container, nestable(at), let children = node.children {
                visit(children, "\(at)/fields", step, node, node.field?.isGroup == true ? node.field : group)
            }
        }
    }
    let steps = definition.steps ?? []
    if !steps.isEmpty {
        for (index, step) in steps.enumerated() { visit(step.fields, "/steps/\(index)/fields", index, nil, nil) }
    } else {
        visit(definition.fields ?? [], "/fields", -1, nil, nil)
    }
    return nodes
}

private func conditionEntries(_ definition: FormDefinition, _ nodes: [NodeEntry]) -> [ConditionEntry] {
    var entries = nodes.flatMap { entry in
        ConditionSite(path: entry.path, owner: .field, step: entry.step, key: entry.node.key, group: entry.group?.key)
            .entries(showLists(entry.node))
    }
    for (index, step) in (definition.steps ?? []).enumerated() {
        entries += ConditionSite(path: "/steps/\(index)", owner: .step, step: index).entries(showLists(step))
        for (position, route) in (step.routes ?? []).enumerated() {
            entries += ConditionSite(path: "/steps/\(index)/routes/\(position)", owner: .route, step: index).entries(showLists(route))
        }
        for name in ["next", "back", "skip"] {
            let site = ConditionSite(path: "/steps/\(index)/\(name)", owner: .action, step: index)
            entries += site.entries(disabledLists(step.button(name).action))
        }
    }
    let submit = definition.json["submit"]?.objectValue.map(FormAction.init(json:))
    entries += ConditionSite(path: "/submit", owner: .action, step: -1).entries(disabledLists(submit))
    entries += ConditionSite(path: "/cancel", owner: .action, step: -1).entries(disabledLists(definition.cancel))
    return entries
}

private struct FieldScopes {
    var keys = ScopedEntries()
    var scopes = StringMap<ScopedEntries>(insertionOrder: true)
    var order: [String] = []

    init(_ entries: [FieldEntry]) {
        for entry in entries {
            guard let group = entry.group else {
                keys.addFirst(entry)
                continue
            }
            if scopes[group.key] == nil { order.append(group.key) }
            scopes[group.key, default: ScopedEntries()].addFirst(entry)
        }
    }
}

struct CheckContext {
    let definition: FormDefinition
    let nodes: [NodeEntry]
    let entries: [FieldEntry]
    let keys: ScopedEntries
    let scopeOrder: [String]
    let scopes: StringMap<ScopedEntries>
    let conditions: [ConditionEntry]
    let validators: KeySet?

    var keyList: [String] { keys.keys }

    func target(_ key: String, group: String? = nil) -> FieldEntry? {
        if let group, let entry = scopes[group]?[key] { return entry }
        return keys[key]
    }

    init(_ definition: FormDefinition, validators: KeySet? = nil) {
        self.definition = definition
        self.validators = validators
        nodes = nodeEntries(definition)
        entries = nodes.compactMap { entry in
            entry.node.field.map { FieldEntry(field: $0, path: entry.path, step: entry.step, group: entry.group, parent: entry.parent) }
        }
        let scoped = FieldScopes(entries)
        keys = scoped.keys
        scopes = scoped.scopes
        scopeOrder = scoped.order
        conditions = conditionEntries(definition, nodes)
    }
}
