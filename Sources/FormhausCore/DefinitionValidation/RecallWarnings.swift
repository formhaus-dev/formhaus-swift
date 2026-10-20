struct RecallText {
    let path: String
    let keys: [String]
    let reserved: [String]
    let step: Int
    let owner: Int
    let group: String?
}

private struct RecallOwner {
    let json: JSONObject
    let ordinal: Int
    let key: String?
    let path: String
    let step: Int
    let group: String?
}

func recallTexts(_ context: CheckContext) -> [RecallText] {
    let steps = (context.definition.steps ?? []).enumerated().map { index, step in
        RecallOwner(json: step.json, ordinal: step.ordinal, key: nil, path: "/steps/\(index)", step: index, group: nil)
    }
    let nodes = context.nodes.map { entry in
        RecallOwner(
            json: entry.node.json, ordinal: entry.node.ordinal, key: entry.node.key, path: entry.path, step: entry.step,
            group: entry.group?.key)
    }
    return (steps + nodes).flatMap { owner in
        recallSlots.compactMap { slot -> RecallText? in
            guard let text = owner.json[slot]?.stringValue else { return nil }
            let keys = recallKeys(text)
            let reserved = reservedTokens(text)
            guard !keys.isEmpty || !reserved.isEmpty else { return nil }
            return RecallText(
                path: "\(owner.path)/\(slot)", keys: keys, reserved: reserved, step: owner.step, owner: owner.ordinal,
                group: slot == "itemLabel" ? owner.key : owner.group)
        }
    }
}

private func sharedKey(_ group: String?, _ key: String) -> String { "\(group ?? "")\n\(key)" }

private func keyWarnings(_ context: CheckContext, _ shared: StringMap<[FormField]>, _ text: RecallText) -> [DefinitionIssue] {
    OrderedKeys(text.keys).keys.flatMap { key -> [DefinitionIssue] in
        let token = "\"{{\(key)}}\""
        guard let target = context.target(key, group: text.group) else {
            return [warning("unknown-recall-field", text.path, "\(token) names no field", "Use the key of an earlier field")]
        }
        let fields = shared[sharedKey(target.group?.key, key)] ?? []
        var issues: [DefinitionIssue] = []
        if target.field.ordinal == text.owner || target.step > text.step {
            issues.append(
                warning(
                    "recall-forward-reference", text.path, "\(token) recalls a field that is not answered yet",
                    "Recall a field from an earlier step"))
        }
        if fields.contains(where: { $0.type == "password" }) {
            issues.append(
                warning("recall-sensitive-field", text.path, "\(token) recalls a password, which shows nothing", "Remove the token"))
        }
        if fields.contains(where: { $0.type == "hidden" && $0.source?.objectValue != nil }) {
            issues.append(
                warning(
                    "recall-query-source", text.path, "\(token) shows text from the page URL, which anyone can write in a link",
                    "Recall it only where any text is safe to show"))
        }
        if fields.contains(where: { $0.type == "hidden" && ["referrer", "pageTitle"].contains($0.source?.stringValue) }) {
            issues.append(
                warning(
                    "recall-untrusted-source", text.path, "\(token) shows the referring page or the page title, which another site can set",
                    "Recall it only where any text is safe to show"))
        }
        return issues
    }
}

func recallWarnings(_ context: CheckContext) -> [DefinitionIssue] {
    guard context.definition.recallsAnswers else { return [] }
    var shared = StringMap<[FormField]>()
    for entry in context.entries { shared[sharedKey(entry.group?.key, entry.field.key), default: []].append(entry.field) }
    return recallTexts(context).flatMap { text in
        let syntax = text.reserved.prefix(1).map { token in
            warning(
                "recall-syntax", text.path, "\"\(token)\" holds more than a field key and shows as written",
                "Put only a field key inside {{ }}, or write \\{{ for literal braces")
        }
        var codes = KeySet()
        return (syntax + keyWarnings(context, shared, text)).filter { codes.insert($0.code.rawValue) }
    }
}
