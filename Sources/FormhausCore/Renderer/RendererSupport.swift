extension FieldOption {
    public init(value: String, label: String, image: String? = nil) {
        var json: JSONObject = ["value": .string(value), "label": .string(label)]
        if let image { json["image"] = .string(image) }
        self.init(json: json)
    }
}

extension FieldOption {
    @_spi(Renderer)
    public var imageKey: Int? { imageDigest }
}

extension FormField {
    @_spi(Renderer)
    public var nodeID: Int { ordinal }

    @_spi(Renderer)
    public var isRequired: Bool { validation?.required?.isTruthy == true }

    @_spi(Renderer)
    public var advancesOnCommit: Bool { autoAdvance?.isTruthy == true }

    @_spi(Renderer)
    public var hasPictureOptions: Bool { hasPictures }
}

extension FormSection {
    @_spi(Renderer)
    public var nodeID: Int { ordinal }
}

extension FormNode {
    @_spi(Renderer)
    public var nodeID: Int { ordinal }
}

extension FormDefinition {
    @_spi(Renderer)
    public var source: JSONObject { json }
}

extension FormStep {
    @_spi(Renderer)
    public var nodeID: Int { ordinal }
}

public struct ItemPath: Sendable, Hashable {
    public let group: String
    public let index: Int
    public let field: String
}

extension FormEngine {
    @_spi(Renderer)
    public var version: Int { core.version }

    @_spi(Renderer)
    public var errorsVersion: Int { core.errorsGeneration }

    @_spi(Renderer)
    public var definitionRevision: Int { core.definitionGeneration }

    @_spi(Renderer)
    public func visibleNodes(of step: FormStep) -> [FormNode] {
        core.visibility.shownNodes(step.fields, core.values.json)
    }

    @_spi(Renderer)
    @discardableResult
    public func autoAdvance() async throws -> Bool {
        try await advance(.autoAdvance)
    }

    @_spi(Renderer)
    public func itemPath(_ key: String) -> ItemPath? {
        core.visibility.parse(key).map { ItemPath(group: $0.group, index: $0.index, field: $0.field) }
    }

    @_spi(Renderer)
    public func value(at key: String) -> JSONValue? {
        guard let path = itemPath(key) else { return core.values[key] }
        let items = itemsOf(core.values[path.group])
        guard items.indices.contains(path.index) else { return nil }
        return items[path.index].objectValue?[path.field]
    }

    @_spi(Renderer)
    public func hasValue(_ key: String) -> Bool {
        guard let value = value(at: key) else { return false }
        return value != .string("")
    }

    @_spi(Renderer)
    public func itemLimits(_ group: FormField) -> (min: Int, max: Int) {
        let limits = core.itemLimits(group)
        return (clampedInt(limits.min, 0...1_000_000) ?? 0, clampedInt(limits.max, 0...1_000_000) ?? maxGroupItems)
    }

    @_spi(Renderer)
    public func itemHasContent(_ key: String, _ index: Int) -> Bool {
        guard let group = core.visibility.groups.first(where: { sameText($0.key, key) }) else { return false }
        let items = itemsOf(core.values[key])
        guard items.indices.contains(index), let item = items[index].objectValue else { return false }
        return group.items.contains { field in
            let raw = item[field.key]
            let value = raw?.stringValue.map { JSONValue.string($0.jsTrimmed) } ?? raw
            return !isBlank(value) && value != .bool(false) && value != field.defaultValue
        }
    }

    @_spi(Renderer)
    public func firstErrorKey() -> String? {
        let errors = core.errors
        guard !errors.isEmpty else { return nil }
        let nodes = currentStep?.fields ?? definition.fields ?? []
        return errorKeys(nodes, errors, core.values.json).first
    }
}

@_spi(Renderer)
public func clampedInt(_ value: Double?, _ range: ClosedRange<Int>) -> Int? {
    guard let value, value.isFinite else { return nil }
    let floor = value.rounded(.down)
    if floor <= Double(range.lowerBound) { return range.lowerBound }
    if floor >= Double(range.upperBound) { return range.upperBound }
    return Int(floor)
}
