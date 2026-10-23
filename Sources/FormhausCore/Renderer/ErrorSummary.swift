import Foundation

public struct ErrorEntry: Sendable, Hashable, Identifiable {
    public let key: String
    public let id: String
    public let label: String
    public let message: String

    public var text: String {
        let closing = label.precomposedStringWithCompatibilityMapping.unicodeScalars.last.map { closingPunctuation.contains($0) } ?? false
        return label + (closing ? " " : ": ") + message
    }
}

public struct ErrorGroup: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let entries: [ErrorEntry]
}

public struct ErrorSummary: Sendable, Hashable {
    public let groups: [ErrorGroup]
    public let topLevelErrors: [String]
    public let count: Int
}

public struct ErrorSummaryOptions: Sendable {
    public var idPrefix: String?
    public var labels: LabelSource?

    public init(idPrefix: String? = nil, labels: LabelSource? = nil) {
        self.idPrefix = idPrefix
        self.labels = labels
    }
}

private let closingPunctuation = Set("?!:.\u{3002}".unicodeScalars)

private func cleanId(_ value: String) -> String {
    String(decoding: value.utf16.map { isWordUnit($0) || $0 == 0x2D ? $0 : 0x2D }, as: UTF16.self)
}

private func assignIds(_ names: [String], _ groups: KeySet = KeySet()) -> StringMap<String> {
    let keys = names.sorted { lhs, rhs in
        let (leftGroup, rightGroup) = (groups.contains(lhs), groups.contains(rhs))
        if leftGroup != rightGroup { return rightGroup }
        if leftGroup { return codeUnitLess(rhs, lhs) }
        let (leftClean, rightClean) = (sameText(cleanId(lhs), lhs), sameText(cleanId(rhs), rhs))
        return leftClean != rightClean ? leftClean : codeUnitLess(lhs, rhs)
    }
    var ids = StringMap<String>()
    var taken: [String] = []
    for key in keys {
        var id = cleanId(key)
        var seed = key
        while taken.containsText(id) || (groups.contains(key) && taken.contains { hasTextPrefix($0, "\(id)--") }) {
            id = "\(cleanId(key))-\(String(fnv1a(seed), radix: 36))"
            seed = id
        }
        taken.append(id)
        ids[key] = id
    }
    return ids
}

private struct DomIds {
    let prefix: String
    let fields: StringMap<String>
    let items: StringMap<StringMap<String>>

    init(_ definition: FormDefinition, _ formId: String?) {
        prefix = formId.flatMap { $0.isEmpty ? nil : cleanId($0) } ?? "fh"
        var names: [String] = []
        var groups = KeySet()
        var itemNames = StringMap<[String]>()
        for node in definition.topNodes.flatMap({ node in [node] + (node.section?.fields ?? []) }) {
            names.append(node.key)
            guard let group = node.field, group.isGroup else { continue }
            groups.insert(group.key)
            itemNames[group.key] = (itemNames[group.key] ?? []) + group.items.map(\.key)
        }
        fields = assignIds(OrderedKeys(names).keys, groups)
        items = itemNames.reduce(into: StringMap<StringMap<String>>()) { $0[$1.0] = assignIds(OrderedKeys($1.1).keys) }
    }

    func field(_ key: String) -> String {
        "\(prefix)-\(fields[key] ?? cleanId(key))"
    }

    func item(_ group: String, _ index: Int, _ key: String) -> String {
        "\(field(group))--\(index)--\(items[group]?[key] ?? cleanId(key))"
    }
}

extension FormEngine {
    fileprivate func errorGroups(_ options: ErrorSummaryOptions) -> [ErrorGroup] {
        let errors = core.errors
        guard !errors.isEmpty else { return [] }
        let ids = DomIds(definition, options.idPrefix)
        let source = options.labels
        let values = core.values.json
        let sections: [(id: String, title: String?, fields: [FormNode])] =
            isMultiStep
            ? visibleSteps.map { ($0.id, recalledTitle($0.json), $0.fields) }
            : [(definition.id, recalledTitle(definition.json), definition.fields ?? [])]
        return sections.enumerated().compactMap { index, section in
            let entries = errorKeys(section.fields, errors, values).compactMap { key -> ErrorEntry? in
                let item = core.visibility.activeItem(key, values)
                guard let raw = item?.field ?? core.visibility.activeField(key, values), let message = errors[key] else { return nil }
                let field = recalled(raw, at: item == nil ? nil : key)
                let name = field.label ?? ""
                let label = item.map { "\(name) (\(itemTitle($0.group, $0.index, source)))" } ?? name
                let id = core.visibility.parse(key).map { ids.item($0.group, $0.index, $0.field) } ?? ids.field(key)
                return ErrorEntry(key: key, id: id, label: label, message: message)
            }
            guard !entries.isEmpty else { return nil }
            let title = section.title.flatMap { $0.isEmpty ? nil : $0 } ?? label("stepTitle", source, ["index": .number(Double(index + 1))])
            return ErrorGroup(id: section.id, title: title, entries: entries)
        }
    }
}

@MainActor
public func errorSummary(_ engine: FormEngine, options: ErrorSummaryOptions = ErrorSummaryOptions()) -> ErrorSummary {
    let groups = engine.errorGroups(options)
    return ErrorSummary(groups: groups, topLevelErrors: engine.topLevelErrors, count: groups.reduce(0) { $0 + $1.entries.count })
}
