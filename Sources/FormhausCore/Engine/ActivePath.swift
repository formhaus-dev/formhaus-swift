private func addStepValues(_ nodes: [FormNode], _ values: JSONObject, _ target: inout JSONObject) {
    let fields = valueFields(nodes)
    let saved = fields.map { ($0.key, target[$0.key]) }
    for field in fields { target[field.key] = trimValue(field, values[field.key]) }
    let shown = shownFields(nodes, target).filter { values[$0.key] != nil }.map { field in
        (field.key, field.isGroup ? cleanItems(field, values[field.key], target) : trimValue(field, values[field.key]))
    }
    for (key, value) in saved { target[key] = value }
    for (key, value) in shown { target[key] = value }
}

struct ActivePath {
    let steps: [FormStep]
    let values: JSONObject

    static func walk(_ definition: FormDefinition, _ values: JSONObject) -> ActivePath {
        let steps = definition.steps ?? []
        let indexes = stepIndexes(steps)
        var result: [FormStep] = []
        var available = JSONObject()
        if steps.isEmpty { addStepValues(definition.fields ?? [], values, &available) }
        var index = 0
        while index < steps.count {
            let step = steps[index]
            guard isVisible(step, available) else {
                index += 1
                continue
            }
            result.append(step)
            addStepValues(step.fields, values, &available)
            let route = step.routes?.first { route in
                guard isVisible(route, available) else { return false }
                if route.endsForm { return true }
                guard let target = route.to.flatMap({ indexes[$0] }) else { return false }
                return target > index && isVisible(steps[target], available)
            }
            if route?.endsForm == true { break }
            index = route.flatMap { $0.to.flatMap { indexes[$0] } } ?? index + 1
        }
        return ActivePath(steps: result, values: available)
    }

    func ordered(_ definition: FormDefinition) -> JSONObject {
        let fields = definition.isMultiStep ? steps.flatMap { valueFields($0.fields) } : valueFields(definition.fields ?? [])
        var sorted = JSONObject()
        for field in fields where !sorted.has(field.key) {
            if let value = values[field.key] { sorted[field.key] = value }
        }
        return sorted
    }

    func contains(_ step: FormStep) -> Bool {
        steps.contains { $0.ordinal == step.ordinal }
    }
}

final class PathCache {
    private let definition: FormDefinition
    private var source: JSONObject?
    private var path = ActivePath(steps: [], values: JSONObject())
    private var ordered: JSONObject?

    init(_ definition: FormDefinition) {
        self.definition = definition
    }

    func path(_ values: JSONObject) -> ActivePath {
        if source != values {
            source = values
            path = ActivePath.walk(definition, values)
            ordered = nil
        }
        return path
    }

    func conditionValues(_ values: JSONObject) -> JSONObject {
        let path = path(values)
        if let ordered { return ordered }
        let result = path.ordered(definition)
        ordered = result
        return result
    }
}

func activeSteps(_ definition: FormDefinition, _ values: JSONObject) -> [FormStep] {
    ActivePath.walk(definition, values).steps
}

func reconcileStepIndex(_ previous: [FormStep], _ next: [FormStep], _ index: Int) -> Int {
    let previousStep = previous.indices.contains(index) ? previous[index] : previous.last
    if let previousStep, let preserved = next.firstIndex(where: { sameText($0.id, previousStep.id) }) { return preserved }
    var before = min(index - 1, previous.count - 1)
    while before >= 0 {
        if let predecessor = next.firstIndex(where: { sameText($0.id, previous[before].id) }) { return predecessor }
        before -= 1
    }
    return 0
}
