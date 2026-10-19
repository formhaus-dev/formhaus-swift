struct OrderedIndex<Value: NodeIdentity> {
    private var storage = StringMap<[Value]>(insertionOrder: true)

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
    let allFields: [FormField]
    private(set) var fieldsByKey = OrderedIndex<FormField>()
    private(set) var routeFields = KeySet()
    private(set) var fieldDependents = OrderedIndex<FormField>()
    private(set) var stepDependents = OrderedIndex<FormStep>()
    private var stepOfField: [Int: FormStep] = [:]
    private var sectionOfField: [Int: FormSection] = [:]

    init(_ definition: FormDefinition) {
        allFields = definition.allFields
        for section in definition.topNodes.compactMap(\.section) {
            for field in section.fields.compactMap(\.field) { sectionOfField[field.ordinal] = section }
        }
        for field in allFields { indexField(field) }
        for step in definition.steps ?? [] { indexStep(step) }
    }

    private func indexField(_ field: FormField) {
        fieldsByKey.insert(field, for: field.key)
        let sources = field.conditionFields + (section(of: field)?.conditionFields ?? []) + field.items.flatMap(\.conditionFields)
        for key in sources { fieldDependents.insert(field, for: key) }
    }

    private func indexStep(_ step: FormStep) {
        for field in valueFields(step.fields) { stepOfField[field.ordinal] = step }
        for key in step.conditionFields { stepDependents.insert(step, for: key) }
        for route in step.routes ?? [] { routeFields.formUnion(route.conditionFields) }
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
