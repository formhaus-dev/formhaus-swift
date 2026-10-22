import Foundation

public struct FormSnapshot: Codable, Sendable, Hashable {
    static let currentVersion = 1

    public let version: Int
    public let definitionId: String?
    public let values: JSONObject
    public let step: String?
    public let skipped: [String]
    public let seed: String

    @MainActor
    public static func decode(_ data: Data, options: FormEngineOptions = FormEngineOptions()) -> FormSnapshot? {
        guard let json = try? JSONValue(parsing: data), let snapshot = FormSnapshot(json: json) else {
            deliver(mismatchWarning(), options)
            return nil
        }
        return snapshot
    }

    init(version: Int, definitionId: String?, values: JSONObject, step: String?, skipped: [String], seed: String) {
        self.version = version
        self.definitionId = definitionId
        self.values = values
        self.step = step
        self.skipped = skipped
        self.seed = seed
    }

    init?(json: JSONValue) {
        guard let object = json.objectValue, let version = object["version"]?.numberValue.flatMap({ Int(exactly: $0) }),
            let values = object["values"]?.objectValue, let entries = object["skipped"]?.arrayValue,
            let seed = object["seed"]?.stringValue, let definitionId = optionalText(object["definitionId"]),
            let step = optionalText(object["step"])
        else { return nil }
        let skipped = entries.compactMap(\.stringValue)
        guard skipped.count == entries.count else { return nil }
        self.init(version: version, definitionId: definitionId, values: values, step: step, skipped: skipped, seed: seed)
    }

    public init(from decoder: any Decoder) throws {
        guard let snapshot = FormSnapshot(json: try JSONValue(from: decoder)) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Not a form snapshot")
            throw DecodingError.dataCorrupted(context)
        }
        self = snapshot
    }

    public func encode(to encoder: any Encoder) throws {
        let json: JSONObject = [
            "version": .number(Double(version)), "definitionId": definitionId.map(JSONValue.string) ?? .null, "values": .object(values),
            "step": step.map(JSONValue.string) ?? .null, "skipped": .array(skipped.map(JSONValue.string)), "seed": .string(seed),
        ]
        try JSONValue.object(json).encode(to: encoder)
    }
}

private func optionalText(_ value: JSONValue?) -> String?? {
    switch value {
    case nil, .null?: .some(nil)
    case .string(let text)?: .some(text)
    default: nil
    }
}

private func mismatchWarning() -> DefinitionIssue {
    warning(
        .snapshotMismatch, "", "The saved progress does not match this form, so the form starts fresh",
        "Discard snapshots saved for another version of the form")
}

private func withoutPasswords(_ values: JSONObject, _ fields: [FormField]) -> JSONObject {
    var result = JSONObject()
    for (key, value) in values {
        let owners = fields.filter { sameText($0.key, key) }
        if owners.contains(where: { $0.type == "password" }) { continue }
        guard let group = owners.first(where: \.isGroup), let items = value.arrayValue else {
            result[key] = value
            continue
        }
        result[key] = .array(items.map { item in item.objectValue.map { .object(withoutPasswords($0, group.items)) } ?? item })
    }
    return result
}

extension FormSnapshot {
    @MainActor
    func matching(_ definition: FormDefinition, _ options: FormEngineOptions) -> FormSnapshot? {
        let steps = definition.steps ?? []
        let id = definition.json["id"]?.stringValue
        let sameForm = id.map { id in definitionId.map { sameText($0, id) } ?? false } ?? (definitionId == nil)
        let knownStep = step.map { step in steps.contains { sameText($0.id, step) } } ?? true
        let skippable = skipped.allSatisfy { id in steps.contains { sameText($0.id, id) && $0.canSkip } }
        guard version == Self.currentVersion, sameForm, knownStep, skippable else {
            deliver(mismatchWarning(), options)
            return nil
        }
        return FormSnapshot(
            version: version, definitionId: definitionId, values: withoutPasswords(values, definition.allFields), step: step,
            skipped: skipped, seed: seed)
    }
}

extension EngineCore {
    func restore(_ snapshot: FormSnapshot) {
        let steps = definition.steps ?? []
        for id in snapshot.skipped {
            guard let step = steps.first(where: { sameText($0.id, id) }) else { continue }
            markSkipped(step.id, valueFields(step.fields).map(\.key))
        }
        if let id = snapshot.step, let target = steps.first(where: { sameText($0.id, id) }) {
            let visible = visibleSteps
            let before = visible.count(where: { $0.ordinal < target.ordinal })
            currentStepIndex = visible.firstIndex { $0.ordinal == target.ordinal } ?? max(0, before - 1)
        }
        visibility.markChanged(true, true)
    }
}

extension FormEngine {
    public func snapshot() -> FormSnapshot {
        FormSnapshot(
            version: FormSnapshot.currentVersion, definitionId: definition.json["id"]?.stringValue,
            values: withoutPasswords(values, definition.allFields), step: isMultiStep ? currentStep?.id : nil,
            skipped: core.skipped.map(\.id), seed: seed)
    }
}
