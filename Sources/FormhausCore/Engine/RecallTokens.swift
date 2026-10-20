let recallSlots = ["title", "description", "label", "placeholder", "helperText", "itemLabel"]

private func tokens(_ text: String) -> [(raw: Substring, token: TemplateToken)] {
    var found: [(raw: Substring, token: TemplateToken)] = []
    forEachToken(text) { range, token in
        found.append((text[range], token))
        return true
    }
    return found
}

func templateTokens(_ text: String) -> [String] {
    tokens(text).compactMap { raw, token in
        switch token {
        case .escape: nil
        case .param(let name): name
        case .recall(let key): key.map { "{{\($0)}}" } ?? String(raw)
        }
    }
}

func recallKeys(_ text: String) -> [String] {
    tokens(text).compactMap { _, token in
        if case .recall(let key?) = token { return key }
        return nil
    }
}

func reservedTokens(_ text: String) -> [String] {
    tokens(text).compactMap { raw, token in
        if case .recall(nil) = token { return String(raw) }
        return nil
    }
}

func formatParts(_ version: JSONValue?) -> (major: Double, minor: Double) {
    let text = version.flatMap { $0.isNull ? nil : jsString($0) } ?? "1.0"
    let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { jsNumber(fromString: String($0)) }
    return (parts[0], parts.count > 1 ? parts[1] : 0)
}
