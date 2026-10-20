let reservedKeys = KeySet([
    "constructor", "__defineGetter__", "__defineSetter__", "hasOwnProperty", "__lookupGetter__", "__lookupSetter__",
    "isPrototypeOf", "propertyIsEnumerable", "toString", "valueOf", "__proto__", "toLocaleString", "prototype",
])

private func isConditional(_ source: Conditional) -> Bool {
    !(source.show ?? []).isEmpty || !(source.showAny ?? []).isEmpty
}

private func successors(_ steps: [FormStep], _ indexes: StringMap<Int>, _ from: Int) -> [Int] {
    var next: [Int] = []
    for route in steps[from].routes ?? [] {
        let target = route.endsForm ? nil : route.to.flatMap { indexes[$0] }
        if route.endsForm && !isConditional(route) { return next }
        guard let target, !route.endsForm, target > from else { continue }
        next.append(target)
        if !isConditional(route) && !isConditional(steps[target]) { return next }
    }
    return from + 1 < steps.count ? next + [from + 1] : next
}

func stepIndexes(_ steps: [FormStep]) -> StringMap<Int> {
    var indexes = StringMap<Int>(insertionOrder: true)
    for (index, step) in steps.enumerated() { indexes[step.id] = index }
    return indexes
}

private final class StepReachability {
    private let steps: [FormStep]
    private let indexes: StringMap<Int>
    private var memo: [Int: Set<Int>] = [:]

    init(_ steps: [FormStep]) {
        self.steps = steps
        indexes = stepIndexes(steps)
    }

    func reaches(_ start: Int, _ target: Int) -> Bool {
        guard steps.indices.contains(start) else { return false }
        if let known = memo[start] { return known.contains(target) }
        var seen = Set<Int>()
        var queue = successors(steps, indexes, start)
        while let index = queue.popLast() {
            if seen.contains(index) { continue }
            seen.insert(index)
            queue.append(contentsOf: successors(steps, indexes, index))
            if isConditional(steps[index]) && index + 1 < steps.count { queue.append(index + 1) }
        }
        memo[start] = seen
        return seen.contains(target)
    }
}

private func stepIssues(_ context: CheckContext) -> [DefinitionIssue] {
    var issues: [DefinitionIssue] = []
    let steps = context.definition.steps ?? []
    var seen = StringMap<Int>(insertionOrder: true)
    for (index, step) in steps.enumerated() {
        if let first = seen[step.id] {
            issues.append(
                error(
                    "duplicate-step-id", "/steps/\(index)/id", "step id \"\(step.id)\" is already used by /steps/\(first)",
                    "Give each step a unique id"))
        } else {
            seen[step.id] = index
        }
    }
    for (index, step) in steps.enumerated() {
        for (position, route) in (step.routes ?? []).enumerated() where !route.endsForm {
            let to = route.to ?? ""
            let target = seen[to]
            if let target, target > index { continue }
            let later = steps[(index + 1)...].map(\.id)
            let problem = target == nil ? "\"\(to)\" is not a step id" : "\"\(to)\" is not a later step"
            let hint = later.isEmpty ? "Use null to end the form here" : "\(oneOf(Array(later))), or null to end the form here"
            issues.append(error("route-target", "/steps/\(index)/routes/\(position)/to", problem, hint))
        }
    }
    return issues
}

private func keyClashes(_ context: CheckContext) -> [NodeEntry?] {
    let reachable = StepReachability(context.definition.steps ?? [])
    let exclusive = { (a: NodeEntry, b: NodeEntry) in a.step != b.step && !reachable.reaches(a.step, b.step) }
    var firstOuter = StringMap<NodeEntry>(insertionOrder: true)
    for entry in context.nodes where entry.group == nil && firstOuter[entry.node.key] == nil { firstOuter[entry.node.key] = entry }
    var earlierOuter = StringMap<[NodeEntry]>(insertionOrder: true)
    var earlierInner: [Int: StringMap<NodeEntry>] = [:]
    return context.nodes.map { entry in
        let key = entry.node.key
        guard let group = entry.group else {
            defer { earlierOuter[key, default: []].append(entry) }
            return earlierOuter[key]?.first { !exclusive($0, entry) }
        }
        let earlier = earlierInner[group.ordinal]?[key]
        if earlier == nil { earlierInner[group.ordinal, default: [:]][key] = entry }
        return earlier ?? firstOuter[key]
    }
}

private func keyIssue(_ entry: NodeEntry, clash: NodeEntry?, prefix: NodeEntry?) -> DefinitionIssue? {
    let key = entry.node.key
    if reservedKeys.contains(key) {
        return error("reserved-key", "\(entry.path)/key", "\"\(key)\" is a built-in object property name", "Rename the field key")
    }
    if let clash {
        let inGroup = entry.group != nil
        return error(
            "duplicate-key", "\(entry.path)/key", "key \"\(key)\" is already used by \(clash.path)\(inGroup ? "" : " on the same path")",
            inGroup ? "Rename the field" : "Rename one of the fields, or move them to route branches that never meet")
    }
    guard let prefix else { return nil }
    return error(
        "duplicate-key", "\(entry.path)/key", "key \"\(key)\" starts with the group key \"\(prefix.node.key).\"", "Rename the field")
}

private func keyIssues(_ context: CheckContext) -> [DefinitionIssue] {
    let groups = context.nodes.filter { $0.group == nil && $0.node.field?.isGroup == true }
    return zip(context.nodes, keyClashes(context)).compactMap { entry, clash in
        let prefix = entry.group == nil ? groups.first { hasTextPrefix(entry.node.key, "\($0.node.key).") } : nil
        return keyIssue(entry, clash: clash, prefix: prefix)
    }
}

private func nestingIssues(_ context: CheckContext) -> [DefinitionIssue] {
    context.nodes.flatMap { entry -> [DefinitionIssue] in
        let section = entry.node.section != nil
        guard let parent = entry.parent, section || (entry.group != nil && ["group", "file", "hidden"].contains(entry.node.type)) else {
            return []
        }
        return [
            error(
                "invalid-nesting", "\(entry.path)/type", "a \(entry.node.type) cannot be inside a \(parent.type)",
                "Move it to the fields of the step")
        ]
    }
}

func structureIssues(_ context: CheckContext) -> [DefinitionIssue] {
    let definition = context.definition
    let both = !(definition.fields ?? []).isEmpty && !(definition.steps ?? []).isEmpty
    let mixed =
        both
        ? [
            error(
                "fields-and-steps", "", "the definition has both \"fields\" and \"steps\"",
                "Move the top-level fields into a step, or remove \"steps\"")
        ] : []
    return mixed + stepIssues(context) + keyIssues(context) + nestingIssues(context)
}
