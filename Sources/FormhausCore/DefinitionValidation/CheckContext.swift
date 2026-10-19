struct FieldEntry {
    let field: FormField
    let path: String
    let step: Int
    let group: FormField?
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
    private var entries = StringMap<FieldEntry>()

    subscript(key: String) -> FieldEntry? { entries[key] }

    mutating func addFirst(_ entry: FieldEntry) {
        let key = entry.field.key
        guard entries[key] == nil else { return }
        entries[key] = entry
        keys.append(key)
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
        let entries = nodes.compactMap { entry in
            entry.node.field.map { FieldEntry(field: $0, path: entry.path, step: entry.step, group: entry.group) }
        }
        var keys = ScopedEntries()
        var scopes = StringMap<ScopedEntries>()
        var scopeOrder: [String] = []
        for entry in entries {
            if let group = entry.group {
                if scopes[group.key] == nil { scopeOrder.append(group.key) }
                scopes[group.key, default: ScopedEntries()].addFirst(entry)
            } else {
                keys.addFirst(entry)
            }
        }
        var conditions: [ConditionEntry] = []
        func collect(_ source: [String: [ShowCondition]?], _ path: String, _ owner: ConditionOwner, _ step: Int, _ key: String? = nil, _ group: String? = nil) {
            let names = owner == .action ? ["disabled"] : ["show", "showAny"]
            for name in names {
                for (index, condition) in ((source[name] ?? nil) ?? []).enumerated() {
                    conditions.append(ConditionEntry(condition: condition, path: "\(path)/\(name)/\(index)", owner: owner, step: step, key: key, group: group))
                }
            }
        }
        func lists(_ source: Conditional) -> [String: [ShowCondition]?] { ["show": source.show, "showAny": source.showAny] }
        func disabled(_ action: FormAction?) -> [String: [ShowCondition]?] { ["disabled": action?.disabled] }
        for entry in nodes { collect(lists(entry.node.conditional), entry.path, .field, entry.step, entry.node.key, entry.group?.key) }
        for (index, step) in steps.enumerated() {
            collect(lists(step), "/steps/\(index)", .step, index)
            for (position, route) in (step.routes ?? []).enumerated() {
                collect(lists(route), "/steps/\(index)/routes/\(position)", .route, index)
            }
            for name in ["next", "back", "skip"] {
                collect(disabled(step.button(name).action), "/steps/\(index)/\(name)", .action, index)
            }
        }
        collect(disabled(definition.json["submit"]?.objectValue.map(FormAction.init(json:))), "/submit", .action, -1)
        collect(disabled(definition.cancel), "/cancel", .action, -1)
        self.nodes = nodes
        self.entries = entries
        self.keys = keys
        self.scopes = scopes
        self.scopeOrder = scopeOrder
        self.conditions = conditions
    }
}
