enum NodeKind {
    case form, step, section, field, group, option, action, validation

    var slots: [String] {
        switch self {
        case .form, .step, .section: ["title", "description"]
        case .group: ["label", "helperText", "itemLabel", "addLabel", "removeLabel"]
        case .field: ["label", "placeholder", "helperText"]
        case .option, .action: ["label"]
        case .validation: ["required", "minLength", "maxLength", "min", "max", "pattern", "matchField"]
        }
    }
}

let defaultLabelKeys = [
    "continue", "back", "stepOf", "errorSummary", "addItem", "removeItem", "itemLabel", "itemAdded", "itemRemoved",
    "removeItemNamed", "removeItemPrompt", "removeItemBody", "cancel",
]

let defaultLabels: [String: String] = [
    "continue": "Continue",
    "back": "Back",
    "stepOf": "Step {current} of {total}",
    "errorSummary": "Check these answers",
    "addItem": "Add",
    "removeItem": "Remove",
    "itemLabel": "{label} {index}",
    "itemAdded": "{item} added",
    "itemRemoved": "{item} removed",
    "removeItemNamed": "{label} {item}",
    "removeItemPrompt": "Remove {item}?",
    "removeItemBody": "This removes {item} and its answers. This cannot be undone.",
    "cancel": "Cancel",
]

func hasRule(_ node: JSONObject, _ slot: String) -> Bool {
    let value = node[slot]
    if slot == "required" { return value?.isTruthy == true }
    return value != nil && value != .bool(false) && value != .string("")
}

struct TextNode {
    let kind: NodeKind
    let node: JSONObject
    let location: [String]
    let path: String
    let address: [String]
    let field: FormField?
}

func textNodes(_ definition: FormDefinition) -> [TextNode] {
    var list: [TextNode] = []
    func add(_ kind: NodeKind, _ node: JSONValue?, _ location: [String], _ address: [String], _ field: FormField? = nil) {
        guard let object = node?.objectValue else { return }
        let path = location.isEmpty ? "" : "/" + location.joined(separator: "/")
        list.append(TextNode(kind: kind, node: object, location: location, path: path, address: address, field: field))
    }
    func actions(_ owner: JSONObject, _ location: [String], _ address: [String], _ names: [String]) {
        for name in names { add(.action, owner[name], location + [name], address + [name]) }
    }
    func fields(_ items: [FormNode], _ location: [String], _ address: [String]) {
        for (index, node) in items.enumerated() {
            let at = location + ["fields", String(index)]
            switch node {
            case .section(let section):
                add(.section, .object(section.json), at, address + ["sections", section.key])
                fields(section.fields, at, address)
            case .field(let field):
                let key = address + ["fields", field.key]
                add(field.isGroup ? .group : .field, .object(field.json), at, key)
                for (position, option) in (field.options ?? []).enumerated() {
                    add(.option, .object(option.json), at + ["options", String(position)], key + ["options", option.value ?? ""])
                }
                add(.validation, field.json["validation"], at + ["validation"], key + ["validation"], field)
                if field.isGroup { fields(field.fields ?? [], at, key) }
            }
        }
    }
    add(.form, .object(definition.json), [], [])
    actions(definition.json, [], [], ["submit", "cancel"])
    let steps = definition.steps ?? []
    for (index, step) in steps.enumerated() {
        let location = ["steps", String(index)]
        let address = ["steps", step.id]
        add(.step, .object(step.json), location, address)
        actions(step.json, location, address, ["next", "back", "skip"])
        fields(step.fields, location, address)
    }
    if steps.isEmpty { fields(definition.fields ?? [], [], []) }
    return list
}

func slotAddress(_ kind: NodeKind, _ address: [String], _ slot: String) -> [String] {
    kind == .option ? address : address + [slot]
}

extension JSONValue {
    mutating func assign(_ value: JSONValue, at location: ArraySlice<String>, key: String) {
        guard let token = location.first else {
            guard case .object(var object) = self else { return }
            object[key] = value
            self = .object(object)
            return
        }
        switch self {
        case .object(var object):
            var child = object[token] ?? .object(JSONObject())
            child.assign(value, at: location.dropFirst(), key: key)
            object[token] = child
            self = .object(object)
        case .array(var items):
            guard let index = Int(token), items.indices.contains(index) else { return }
            items[index].assign(value, at: location.dropFirst(), key: key)
            self = .array(items)
        default:
            return
        }
    }
}
