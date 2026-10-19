struct OrderedIndex<Value: NodeIdentity> {
    private var storage = StringMap<[Value]>()

    var keys: [String] { storage.keys }

    subscript(key: String) -> [Value]? { storage[key] }

    func has(_ key: String) -> Bool { storage.has(key) }

    mutating func insert(_ value: Value, for key: String) {
        var list = storage[key] ?? []
        guard !list.contains(where: { $0.ordinal == value.ordinal }) else { return }
        list.append(value)
        storage[key] = list
    }
}

final class DefinitionIndex {
    let definition: FormDefinition
    let allFields: [FormField]
    private(set) var fieldsByKey = OrderedIndex<FormField>()
    private(set) var routeFields = KeySet()
    private(set) var fieldDependents = OrderedIndex<FormField>()
    private(set) var stepDependents = OrderedIndex<FormStep>()
    private var stepOfField: [Int: FormStep] = [:]
    private var sectionOfField: [Int: FormSection] = [:]

    init(_ definition: FormDefinition) {
        self.definition = definition
        allFields = definition.allFields
        for node in definition.topNodes {
            guard let section = node.section else { continue }
            for field in section.fields.compactMap(\.field) { sectionOfField[field.ordinal] = section }
        }
        for field in allFields {
            fieldsByKey.insert(field, for: field.key)
            for key in field.conditionFields { fieldDependents.insert(field, for: key) }
            if let section = section(of: field) {
                for key in section.conditionFields { fieldDependents.insert(field, for: key) }
            }
            for item in field.items {
                for key in item.conditionFields { fieldDependents.insert(field, for: key) }
            }
        }
        for step in definition.steps ?? [] {
            for field in valueFields(step.fields) { stepOfField[field.ordinal] = step }
            for key in step.conditionFields { stepDependents.insert(step, for: key) }
            for route in step.routes ?? [] { routeFields.formUnion(route.conditionFields) }
        }
    }

    func step(of field: FormField) -> FormStep? { stepOfField[field.ordinal] }

    func section(of field: FormField) -> FormSection? { sectionOfField[field.ordinal] }

    func conditionSources(_ field: FormField) -> [String] {
        field.conditionFields + (section(of: field)?.conditionFields ?? []) + (step(of: field)?.conditionFields ?? [])
            + field.items.flatMap(\.conditionFields)
    }

    func isShared(_ key: String) -> Bool {
        (fieldsByKey[key]?.count ?? 0) > 1
    }
}
