private func counts(_ texts: [String]) -> StringMap<Int> {
    var result = StringMap<Int>()
    for text in texts { result[text, default: 0] += 1 }
    return result
}

@_spi(Renderer)
public func optionTexts(_ options: [FieldOption]) -> [String] {
    let labels = counts(options.map { $0.label ?? "" })
    let texts = options.map { option in
        let label = option.label ?? ""
        return labels[label] ?? 0 > 1 ? "\(label) (\(option.value ?? ""))" : label
    }
    let repeated = counts(texts)
    var taken = KeySet(texts)
    var next = StringMap<Int>()
    return texts.map { text in
        guard repeated[text] ?? 0 > 1 else { return text }
        var index = next[text] ?? 1
        while taken.contains("\(text) (\(index))") { index += 1 }
        next[text] = index + 1
        taken.insert("\(text) (\(index))")
        return "\(text) (\(index))"
    }
}
