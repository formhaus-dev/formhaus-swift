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

func reachableSteps(_ steps: [FormStep]) -> [Set<Int>] {
    let indexes = stepIndexes(steps)
    return steps.indices.map { start in
        var seen = Set<Int>()
        var queue = successors(steps, indexes, start)
        while let index = queue.popLast() {
            if seen.contains(index) { continue }
            seen.insert(index)
            queue.append(contentsOf: successors(steps, indexes, index))
            if isConditional(steps[index]) && index + 1 < steps.count { queue.append(index + 1) }
        }
        return seen
    }
}

private func stepIssues(_ context: CheckContext) -> [DefinitionIssue] {
    var issues: [DefinitionIssue] = []
    let steps = context.definition.steps ?? []
    var seen = StringMap<Int>(insertionOrder: true)
    for (index, step) in steps.enumerated() {
        if let first = seen[step.id] {
            issues.append(error("duplicate-step-id", "/steps/\(index)/id", "step id \"\(step.id)\" is already used by /steps/\(first)", "Give each step a unique id"))
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

private func keyIssues(_ context: CheckContext) -> [DefinitionIssue] {
    let reachable = reachableSteps(context.definition.steps ?? [])
    let exclusive = { (a: NodeEntry, b: NodeEntry) in
        a.step != b.step && !(reachable.indices.contains(a.step) && reachable[a.step].contains(b.step))
    }
    let outer = context.nodes.filter { $0.group == nil }
    let groups = outer.filter { $0.node.field?.isGroup == true }
    var firstOuter = StringMap<NodeEntry>(insertionOrder: true)
    for entry in outer where firstOuter[entry.node.key] == nil { firstOuter[entry.node.key] = entry }
    var earlierOuter = StringMap<[NodeEntry]>(insertionOrder: true)
    var earlierInner: [Int: StringMap<NodeEntry>] = [:]
    var issues: [DefinitionIssue] = []
    for entry in context.nodes {
        let key = entry.node.key
        let clash: NodeEntry?
        if let group = entry.group {
            let id = group.ordinal
            clash = earlierInner[id]?[key] ?? firstOuter[key]
            if earlierInner[id]?[key] == nil { earlierInner[id, default: [:]][key] = entry }
        } else {
            clash = earlierOuter[key]?.first { !exclusive($0, entry) }
            earlierOuter[key, default: []].append(entry)
        }
        let prefix = entry.group == nil ? groups.first { hasTextPrefix(key, "\($0.node.key).") } : nil
        if reservedKeys.contains(key) {
            issues.append(error("reserved-key", "\(entry.path)/key", "\"\(key)\" is a built-in object property name", "Rename the field key"))
        } else if let clash {
            let inGroup = entry.group != nil
            issues.append(
                error(
                    "duplicate-key", "\(entry.path)/key", "key \"\(key)\" is already used by \(clash.path)\(inGroup ? "" : " on the same path")",
                    inGroup ? "Rename the field" : "Rename one of the fields, or move them to route branches that never meet"
                )
            )
        } else if let prefix {
            issues.append(error("duplicate-key", "\(entry.path)/key", "key \"\(key)\" starts with the group key \"\(prefix.node.key).\"", "Rename the field"))
        }
    }
    return issues
}

private func nestingIssues(_ context: CheckContext) -> [DefinitionIssue] {
    context.nodes.flatMap { entry -> [DefinitionIssue] in
        let section = entry.node.section != nil
        guard (section && entry.parent != nil) || (entry.group != nil && ["group", "file", "hidden"].contains(entry.node.type)) else { return [] }
        return [error("invalid-nesting", "\(entry.path)/type", "a \(entry.node.type) cannot be inside a \(entry.parent!.type)", "Move it to the fields of the step")]
    }
}

func structureIssues(_ context: CheckContext) -> [DefinitionIssue] {
    let definition = context.definition
    let both = !(definition.fields ?? []).isEmpty && !(definition.steps ?? []).isEmpty
    let mixed = both ? [error("fields-and-steps", "", "the definition has both \"fields\" and \"steps\"", "Move the top-level fields into a step, or remove \"steps\"")] : []
    return mixed + stepIssues(context) + keyIssues(context) + nestingIssues(context)
}
