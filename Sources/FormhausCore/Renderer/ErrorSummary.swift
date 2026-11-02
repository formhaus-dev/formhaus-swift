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

extension EngineCore {
    fileprivate var currentDomIds: DomIds {
        if let cached = domIds, cached.generation == definitionGeneration { return cached.ids }
        let ids = DomIds(definition)
        domIds = (definitionGeneration, ids)
        return ids
    }
}

extension FormEngine {
    fileprivate func errorGroups(_ options: ErrorSummaryOptions) -> [ErrorGroup] {
        let errors = core.errors
        guard !errors.isEmpty else { return [] }
        let ids = core.currentDomIds
        let prefix = options.idPrefix.flatMap { $0.isEmpty ? nil : cleanId($0) } ?? "fh"
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
                let id = core.visibility.parse(key).map { ids.item(prefix, $0.group, $0.index, $0.field) } ?? ids.field(prefix, key)
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
