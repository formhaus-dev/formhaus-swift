struct ItemField {
    let group: FormField
    let index: Int
    let field: FormField
}

struct VisibilityView {
    var visibleSteps: [FormStep] = []
    var currentStep: FormStep?
    var visibleFields: [FormField] = []
    var visibleNodes: [FormNode] = []
}

final class VisibilityState {
    let definition: FormDefinition
    let index: DefinitionIndex
    let groups: [FormField]
    let paths: PathCache
    let conditional: [FormField]
    let customSteps: [Int]
    let order: [String]
    var starts = StartValues()
    var settled = false
    var waiting = KeySet()
    private var visibilityDirty = true
    private var canGoNextDirty = true
    private var view = VisibilityView()
    private var canGoNext = false

    init(_ definition: FormDefinition) {
        self.definition = definition
        index = DefinitionIndex(definition)
        groups = index.allFields.filter(\.isGroup)
        paths = PathCache(definition)
        let index = index
        conditional = index.allFields.filter { $0.isConditioned || index.section(of: $0)?.isConditioned == true }
        customSteps = (definition.steps ?? []).filter { customRules($0.fields) }.map(\.ordinal)
        order = OrderedKeys(index.fieldDependents.keys + index.stepDependents.keys).keys
    }

    var allFields: [FormField] { index.allFields }

    func scope(_ values: JSONObject) -> JSONObject { paths.path(values).values }

    func conditionValues(_ values: JSONObject) -> JSONObject { paths.conditionValues(values) }

    func visible(_ field: FormField, _ values: JSONObject) -> Bool {
        let active = scope(values)
        let section = index.section(of: field)
        let limits = definition.listLimits
        return (section.map { isVisible($0, active, limits: limits) } ?? true) && isVisible(field, active, limits: limits)
    }

    func onPath(_ field: FormField, _ values: JSONObject) -> Bool {
        guard let step = index.step(of: field) else { return true }
        return paths.path(values).contains(step)
    }

    func activeField(_ key: String, _ values: JSONObject) -> FormField? {
        index.fieldsByKey[key]?.first { onPath($0, values) && visible($0, values) }
    }

    func parse(_ key: String) -> (group: String, index: Int, field: String)? {
        if index.fieldsByKey.has(key) { return nil }
        for group in groups {
            if let (position, field) = splitPath(group.key, key) { return (group.key, position, field) }
        }
        return nil
    }

    func owner(_ key: String) -> String { parse(key)?.group ?? key }

    func itemFields(_ group: FormField, _ item: JSONValue?, _ values: JSONObject) -> [FormField] {
        let scope = itemScope(group, item ?? .null, scope(values))
        return group.items.filter { isVisible($0, scope, limits: definition.listLimits) }
    }

    func activeItem(_ key: String, _ values: JSONObject) -> ItemField? {
        guard let (groupKey, position, fieldKey) = parse(key), let group = activeField(groupKey, values), group.isGroup else { return nil }
        let items = itemsOf(values[groupKey])
        guard position < items.count, let field = itemFields(group, items[position], values).first(where: { sameText($0.key, fieldKey) })
        else {
            return nil
        }
        return ItemField(group: group, index: position, field: field)
    }

    func state(_ values: JSONObject, _ stepIndex: Int) -> VisibilityView {
        guard visibilityDirty else { return view }
        visibilityDirty = false
        let multi = definition.isMultiStep
        let steps = multi ? paths.path(values).steps : []
        let current = multi ? (steps.indices.contains(stepIndex) ? steps[stepIndex] : steps.last) : nil
        let source = multi ? current?.fields ?? [] : definition.fields ?? []
        let active = scope(values)
        let limits = definition.listLimits
        view = VisibilityView(
            visibleSteps: steps, currentStep: current, visibleFields: shownFields(source, active, limits),
            visibleNodes: source.filter { isVisible($0, active, limits: limits) }.map { node in
                guard let section = node.section else { return node }
                return .section(section.filtered { isVisible($0, active, limits: limits) })
            }
        )
        return view
    }

    func markChanged(_ structureChanged: Bool, _ valuesChanged: Bool) {
        if structureChanged { visibilityDirty = true }
        if structureChanged || valuesChanged { canGoNextDirty = true }
    }

    func canGoNext(_ values: JSONObject, _ stepIndex: Int, _ validators: Validators) -> Bool {
        let step = state(values, stepIndex).currentStep
        guard canGoNextDirty else { return canGoNext }
        canGoNextDirty = false
        if let step, customSteps.contains(step.ordinal) { settled = false }
        let scope = conditionValues(values)
        let errors =
            step.map {
                validateShown($0.fields, scope, scope, ShownChecks(validators: validators, messages: nil, limits: definition.listLimits))
            } ?? FieldErrors()
        canGoNext = definition.isMultiStep && errors.isEmpty
        return canGoNext
    }

    func findStepIndex(_ fieldKey: String, _ values: JSONObject, _ stepIndex: Int) -> Int? {
        let key = owner(fieldKey)
        return state(values, stepIndex).visibleSteps.firstIndex { valueFields($0.fields).contains { sameText($0.key, key) } }
    }

    func affectsStructure(_ key: String, _ cleared: KeySet) -> Bool {
        index.routeFields.contains(key) || index.fieldDependents.has(key) || index.stepDependents.has(key) || !cleared.isEmpty
    }

    func conditionResults(_ values: Values) -> StringMap<(String, Bool)> {
        var results = StringMap<(String, Bool)>(insertionOrder: true)
        for field in conditional {
            results[field.key] = (field.key, (results[field.key]?.1 ?? false) || visible(field, values.json))
        }
        for group in groups {
            for (position, item) in itemsOf(values[group.key]).enumerated() {
                let shown = itemFields(group, item, values.json)
                let id = item.objectValue != nil ? values.itemId(group.key, position).map { "i\($0)" } ?? "\(position)" : "\(position)"
                for field in group.items where field.isConditioned {
                    results["\(group.key) \(id) \(field.key)"] = (
                        itemPath(group.key, position, field.key), shown.contains { $0.ordinal == field.ordinal }
                    )
                }
            }
        }
        return results
    }

    func unsettle() { settled = false }
}

struct OrderedKeys {
    private(set) var keys: [String] = []

    init(_ items: [String]) {
        var seen = KeySet()
        for item in items where seen.insert(item) { keys.append(item) }
    }
}

extension FormSection {
    func filtered(_ include: (FormField) -> Bool) -> FormSection {
        var copy = self
        copy.fields = fields.filter { node in node.field.map(include) ?? false }
        return copy
    }
}
