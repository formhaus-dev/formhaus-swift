private let hyphen = UInt8(ascii: "-")
private let revealBytes = Array("reveal".utf8)
private let descriptionPart = "-description"
private let descriptionBytes = Array(descriptionPart.utf8)
private let numberedMark = "#"
private let groupParts = ["-", "-confirm", "-confirm-title", "-confirm-description"]
private let anchorParts = ["-anchor-0", "-anchor-1", "-anchor-2"]
private let listedParts = [numberedMark, descriptionPart, "-0", "-1", "-2"]

func cleanId(_ value: String) -> String {
    String(decoding: value.utf16.map { isWordUnit($0) || $0 == 0x2D ? $0 : 0x2D }, as: UTF16.self)
}

private func starts(_ text: [UInt8], _ prefix: [UInt8], at index: Int) -> Bool {
    index + prefix.count <= text.count && text[index..<index + prefix.count].elementsEqual(prefix)
}

func baseId(_ key: String) -> String {
    let text = Array(cleanId(key).utf8)
    var result: [UInt8] = []
    result.reserveCapacity(text.count)
    var index = 0
    while index < text.count {
        var end = index
        while end < text.count && text[end] == hyphen { end += 1 }
        if end - index >= 2 && starts(text, revealBytes, at: end) {
            result.append(hyphen)
        } else {
            result += text[index..<max(end, index + 1)]
        }
        index = max(end, index + 1)
    }
    return asciiText(result[...])
}

private func numberedTail(_ text: [UInt8], _ from: Int) -> Bool {
    var index = from
    while index < text.count && (0x30...0x39).contains(text[index]) { index += 1 }
    guard index > from else { return false }
    return index == text.count || (text.count - index == descriptionBytes.count && starts(text, descriptionBytes, at: index))
}

private func isNumbered(_ part: String) -> Bool {
    let bytes = Array(part.utf8)
    return bytes.first == hyphen && numberedTail(bytes, 1)
}

private func numberedEnd(_ id: [UInt8]) -> Int {
    for index in id.indices where id[index] == hyphen && numberedTail(id, index + 1) { return index }
    return 0
}

private func ends(_ id: [UInt8], _ longest: Int) -> [Int] {
    var found: [Int] = []
    var index = id.count - 1
    while index > 0 && index >= id.count - longest {
        if id[index] == hyphen { found.append(index) }
        index -= 1
    }
    return found
}

private func asciiText(_ bytes: ArraySlice<UInt8>) -> String {
    String(String.UnicodeScalarView(bytes.lazy.map(Unicode.Scalar.init)))
}

private func slice(_ id: [UInt8], _ range: Range<Int>) -> String {
    asciiText(id[range])
}

private func holds(_ owner: Set<String>, _ part: String) -> Bool {
    owner.contains(part) || (owner.contains(numberedMark) && isNumbered(part))
}

private func covers(_ owner: Set<String>, _ rest: String, _ parts: [String]) -> Bool {
    holds(owner, rest) || parts.contains { holds(owner, rest + $0) }
}

private func truthy(_ value: JSONValue?) -> Bool { value?.isTruthy == true }

private func scaleParts(_ field: FormField, _ options: [JSONValue]) -> [String] {
    guard let range = field.scaleRange else { return [] }
    let span = range.max - range.min + 1
    let count = span.isNaN ? 0 : Int(min(11, max(0, span)))
    let points = (0..<count).map { "-\(jsString(.number(range.min + Double($0))))" }
    return options.isEmpty ? points : points + anchorParts
}

private func optionParts(_ field: FormField, _ options: [JSONValue]) -> [String] {
    let described = { (option: JSONValue) in truthy(option.objectValue?["description"]) }
    let parts = options.enumerated().flatMap { index, option in ["-\(index)", described(option) ? "-\(index)\(descriptionPart)" : ""] }
    if truthy(field.json["optionsFrom"]) || options.isEmpty { return parts + listedParts }
    return described(options[0]) ? parts + [descriptionPart] : parts
}

private func fieldParts(_ field: FormField) -> [String] {
    let type = field.type
    if type == "hidden" { return [] }
    var parts = ["-error", truthy(field.json["helperText"]) ? "-helper" : ""]
    if field.isGroup { return parts + groupParts }
    let choice = type == "radio" || type == "multiselect"
    let options = field.json["options"]?.arrayValue ?? []
    if !choice && !field.isScale && type != "checkbox" { parts.append("-label") }
    parts.append(type == "autocomplete" ? "-list" : type == "file" && truthy(field.json["multiple"]) ? "-notice" : "")
    parts += scaleParts(field, options)
    return choice ? parts + optionParts(field, options) : parts
}

private func partsOf(_ node: FormNode) -> [String] {
    switch node {
    case .section(let section): truthy(section.json["description"]) ? [descriptionPart] : []
    case .field(let field): fieldParts(field)
    }
}

private struct IdAssignment {
    private var taken: [String: Set<String>] = [:]
    private var numbered = Set<String>()
    private var nested = Set<String>()
    private var tails: [String: [(rest: String, parts: [String])]] = [:]
    private let longest: Int
    private let groups: KeySet
    private(set) var ids = StringMap<String>()

    init(_ names: StringMap<[String]>, groups: KeySet) {
        self.groups = groups
        longest = names.keys.lazy.compactMap { names[$0] }.flatMap { $0 }.map(\.utf8.count).max() ?? 0
        let plain = KeySet(names.keys.filter { sameText(baseId($0), $0) })
        let ordered = names.keys.sorted { lhs, rhs in
            let (leftGroup, rightGroup) = (groups.contains(lhs), groups.contains(rhs))
            if leftGroup != rightGroup { return rightGroup }
            if leftGroup { return codeUnitLess(rhs, lhs) }
            let (leftPlain, rightPlain) = (plain.contains(lhs), plain.contains(rhs))
            return leftPlain != rightPlain ? leftPlain : codeUnitLess(lhs, rhs)
        }
        for key in ordered { ids[key] = assign(key, names[key] ?? []) }
    }

    private func claims(_ id: [UInt8], _ index: Int, _ parts: [String]) -> Bool {
        guard let owner = taken[slice(id, 0..<index)] else { return false }
        return covers(owner, slice(id, index..<id.count), parts)
    }

    private func clashes(_ key: String, _ id: String, _ parts: [String], _ own: Set<String>) -> Bool {
        if taken[id] != nil || (groups.contains(key) && nested.contains(id)) { return true }
        let bytes = Array(id.utf8)
        let end = numberedEnd(bytes)
        if ends(bytes, longest).contains(where: { claims(bytes, $0, parts) }) || (end > 0 && claims(bytes, end, parts)) { return true }
        return (own.contains(numberedMark) && numbered.contains(id)) || (tails[id] ?? []).contains { covers(own, $0.rest, $0.parts) }
    }

    private mutating func assign(_ key: String, _ parts: [String]) -> String {
        let own = Set(parts)
        let base = baseId(key)
        var id = base
        var seed = key
        while clashes(key, id, parts, own) {
            id = "\(base)-\(String(fnv1a(seed), radix: 36))"
            seed = id
        }
        taken[id] = own
        let bytes = Array(id.utf8)
        let end = numberedEnd(bytes)
        if end > 0 { numbered.insert(slice(bytes, 0..<end)) }
        for index in ends(bytes, longest) { tails[slice(bytes, 0..<index), default: []].append((slice(bytes, index..<bytes.count), parts)) }
        for index in bytes.indices.dropLast() where bytes[index] == hyphen && bytes[index + 1] == hyphen {
            nested.insert(slice(bytes, 0..<index))
        }
        return id
    }
}

struct DomIds {
    private let scopes: StringMap<StringMap<String>>

    init(_ definition: FormDefinition) {
        var names: StringMap<StringMap<[String]>> = ["": StringMap()]
        var groups = KeySet()
        func add(_ scope: String, _ node: FormNode) {
            var keys = names[scope] ?? StringMap()
            keys[node.key] = (keys[node.key] ?? []) + partsOf(node)
            names[scope] = keys
        }
        for node in definition.topNodes.flatMap({ node in [node] + (node.section?.fields ?? []) }) {
            add("", node)
            guard let group = node.field, group.isGroup else { continue }
            groups.insert(group.key)
            for field in group.items { add(".\(group.key)", .field(field)) }
        }
        var scopes = StringMap<StringMap<String>>()
        for scope in names.keys {
            scopes[scope] = IdAssignment(names[scope] ?? StringMap(), groups: scope.isEmpty ? groups : KeySet()).ids
        }
        self.scopes = scopes
    }

    private func nodeId(_ key: String, _ scope: String) -> String {
        scopes[scope]?[key] ?? baseId(key)
    }

    func field(_ prefix: String, _ key: String) -> String {
        "\(prefix)-\(nodeId(key, ""))"
    }

    func item(_ prefix: String, _ group: String, _ index: Int, _ key: String) -> String {
        "\(field(prefix, group))--\(index)--\(nodeId(key, ".\(group)"))"
    }
}
