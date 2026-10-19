import Foundation
@testable import FormhausCore
import Testing

struct ScenarioFile: Sendable {
    let name: String
    let definition: JSONValue
    let overlay: JSONValue?
    let scenarios: [JSONObject]

    func definition(of scenario: JSONObject) -> JSONValue {
        scenario["definition"] ?? definition
    }

    func runtime(_ scenario: JSONObject) throws -> FormDefinition {
        let source = definition(of: scenario)
        guard let overlay else { return try FormDefinition(json: source) }
        return try localize(source, overlay: overlay).definition
    }
}

enum Scenarios {
    static let directory = Corpus.directory.appendingPathComponent("scenarios")

    static let files: [ScenarioFile] = Corpus.jsonFiles(in: directory).filter { $0 != "scenario.schema" }.map { name in
        let json = Corpus.load(directory.appendingPathComponent("\(name).json"))
        return ScenarioFile(
            name: name, definition: json["definition"] ?? .null, overlay: json["overlay"],
            scenarios: json["scenarios"]?.arrayValue?.compactMap(\.objectValue) ?? []
        )
    }

    static let ids: [String] = files.flatMap { file in file.scenarios.map { "\(file.name): \($0["name"]?.stringValue ?? "")" } }

    static func lookup(_ id: String) throws -> (ScenarioFile, JSONObject) {
        let separator = try #require(id.range(of: ": "))
        let fileName = String(id[..<separator.lowerBound])
        let name = String(id[separator.upperBound...])
        let file = try #require(files.first { sameUnits($0.name, fileName) })
        let matches = file.scenarios.filter { sameUnits($0["name"]?.stringValue ?? "", name) }
        try #require(matches.count == 1, "\(matches.count) scenarios named \(id)")
        return (file, matches[0])
    }
}

func canonical(_ value: JSONValue?) -> JSONValue {
    switch value {
    case nil, .null?: return .null
    case .number(let number)?: return number.isFinite ? .number(number == 0 ? 0 : number) : .null
    case .array(let items)?: return .array(items.map(canonical))
    case .object(let object)?:
        var result = JSONObject()
        for (key, item) in object { result[key] = canonical(item) }
        return .object(result)
    case let other?: return other
    }
}

func jsonEqual(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    strictlyEqual(canonical(lhs), canonical(rhs))
}

func render(_ value: JSONValue?) -> String {
    switch value {
    case nil, .null?: return "null"
    case .bool(let flag)?: return flag ? "true" : "false"
    case .number(let number)?: return number.rounded() == number && abs(number) < 1e15 ? String(Int(number)) : String(number)
    case .string(let text)?:
        let data = (try? JSONSerialization.data(withJSONObject: [text], options: [.fragmentsAllowed])) ?? Data()
        return String(decoding: data, as: UTF8.self).dropFirst().dropLast().description
    case .array(let items)?: return "[" + items.map(render).joined(separator: ",") + "]"
    case .object(let object)?: return "{" + object.map { "\(render(.string($0.key))):\(render($0.value))" }.joined(separator: ",") + "}"
    }
}

func json(_ strings: [String]) -> JSONValue {
    .array(strings.map(JSONValue.string))
}

func json(_ event: FormEvent) -> JSONValue {
    var object: JSONObject = ["type": .string(event.type)]
    switch event {
    case .stepViewed(let stepId, let stepIndex):
        object["stepId"] = .string(stepId)
        object["stepIndex"] = .number(Double(stepIndex))
    case .fieldError(let fieldKey, let error):
        object["fieldKey"] = .string(fieldKey)
        object["error"] = .string(error)
    case .fieldShown(let fieldKey), .fieldHidden(let fieldKey):
        object["fieldKey"] = .string(fieldKey)
    case .stepCompleted(let stepId), .stepSkipped(let stepId):
        object["stepId"] = .string(stepId)
    case .formSubmitted(let fieldCount):
        object["fieldCount"] = .number(Double(fieldCount))
    case .formSubmitFailed(let reason):
        object["reason"] = .string(reason.rawValue)
    case .formViewed, .formSubmitSucceeded, .formReset:
        break
    }
    return .object(object)
}

func json(_ context: StepChangeContext) -> JSONValue {
    [
        "fromStepId": .string(context.fromStepId), "toStepId": .string(context.toStepId),
        "reason": .string(context.reason.rawValue), "values": .object(context.values),
    ]
}

func errorProjection(_ error: any Error, _ expected: JSONObject) -> JSONValue {
    var object = JSONObject()
    var message: String
    switch error {
    case let failure as ScriptError:
        object["name"] = "Error"
        message = failure.message
    case let failure as FormLifecycleError:
        object["name"] = "FormLifecycleError"
        object["phase"] = .string(failure.phase.rawValue)
        message = failure.message
    case is FormDefinitionError:
        object["name"] = "FormDefinitionError"
        message = String(describing: error)
    default:
        object["name"] = .string(String(describing: type(of: error)))
        message = String(describing: error)
    }
    if expected.has("message") { object["message"] = .string(message) }
    return .object(object)
}

func fieldErrors(_ value: JSONValue?) -> FieldErrors? {
    guard let object = value?.objectValue else { return nil }
    var errors = FieldErrors()
    for (key, message) in object { errors[key] = jsString(message) }
    return errors
}

func truthy(_ value: JSONValue?) -> Bool {
    value?.isTruthy == true
}

func flag(_ value: JSONValue?) -> Bool? {
    value?.boolValue
}
