@_spi(Renderer) import FormhausCore
import Testing

private func attachments(_ version: String?, multiple: JSONValue? = true, validation: JSONObject = ["minLength": 1]) -> JSONValue {
    var field: JSONObject = ["key": "docs", "type": "file", "label": "Documents", "validation": .object(validation)]
    if let multiple { field["multiple"] = multiple }
    var definition: JSONObject = ["id": "attachments", "title": "Attachments", "submit": ["label": "Send"], "fields": [.object(field)]]
    if let version { definition["formatVersion"] = .string(version) }
    return .object(definition)
}

private let reference = "Must be a file reference"

struct ServerCase: Sendable, CustomTestStringConvertible {
    let version: String
    let input: JSONValue
    let values: JSONObject
    let error: String?

    var testDescription: String { "\(version) \(input.jsonString())" }
}

private let serverCases = [
    ServerCase(version: "1.7", input: ["upload-1", "upload-2"], values: ["docs": ["upload-1", "upload-2"]], error: nil),
    ServerCase(version: "1.7", input: "upload-1", values: ["docs": ["upload-1"]], error: nil),
    ServerCase(version: "1.7", input: [], values: ["docs": []], error: nil),
    ServerCase(version: "1.7", input: ["upload-1", 5], values: [:], error: reference),
    ServerCase(version: "1.7", input: ["upload-1", "", nil], values: ["docs": ["upload-1"]], error: nil),
    ServerCase(version: "1.7", input: [["name": "a.pdf"]], values: [:], error: reference),
    ServerCase(version: "1.7", input: ["id": "upload-1"], values: [:], error: reference),
    ServerCase(version: "1.6", input: "upload-1", values: ["docs": "upload-1"], error: nil),
    ServerCase(version: "1.6", input: ["upload-1"], values: [:], error: reference),
]

private let entryCases: [(JSONValue, String?)] = [
    (JSONValue.array([5]), reference), (JSONValue.array([["id": "x"]]), reference), (JSONValue.array(["upload-1", true]), reference),
    (JSONValue.array([["name": "a.pdf"]]), nil), (JSONValue.array(["", nil]), "This field is required"),
    (JSONValue.array(["a", "", nil, "b"]), nil), (JSONValue.array(["a", "b", "c", "d", ""]), "At most 3 allowed"),
]

@Suite("File lists")
@MainActor
struct FileListTests {
    @Test("validateSubmission reads a file list as string references", arguments: serverCases)
    func server(testCase: ServerCase) throws {
        let definition = attachments(testCase.version, validation: [:])
        let result = try validateSubmission(definition, ["docs": testCase.input], options: SubmissionOptions(skippedSteps: []))
        #expect(result.values == testCase.values)
        #expect(result.errors["docs"] == testCase.error)
    }

    @Test("below 1.7 multiple changes nothing", arguments: [nil, "1.0", "1.6"] as [String?], ["upload-1", "", nil] as [JSONValue?])
    func outdated(version: String?, value: JSONValue?) throws {
        let values: JSONObject = value.map { ["docs": $0] } ?? [:]
        let plain = try FormEngine(definition: attachments(version, multiple: nil), values: values)
        let listed = try FormEngine(definition: attachments(version), values: values)
        let lists = listed.definition.allFields.filter(\.isFileList)
        #expect(lists.isEmpty)
        #expect(listed.validate() == plain.validate())
        #expect(listed.getSubmitValues().jsonString() == plain.getSubmitValues().jsonString())
        let server = try validateSubmission(attachments(version), .object(values))
        let before = try validateSubmission(attachments(version, multiple: nil), .object(values))
        #expect(server == before)
    }

    @Test("minLength and maxLength count the files and translate as item counts")
    func messageSlots() throws {
        let listed = textSlots(try FormDefinition(json: attachments("1.7"))).map(\.address)
        let single = textSlots(try FormDefinition(json: attachments("1.7", multiple: false))).map(\.address)
        let labels = ["removeItem", "removeItemNamed", "itemAdded", "itemRemoved"].map { "labels.\($0)" }
        #expect(labels.allSatisfy(listed.contains))
        #expect(!labels.contains(where: single.contains))
        #expect(listed.contains("messages.minItems") && listed.contains("messages.maxItems"))
        #expect(single.contains("messages.minLength") && !single.contains("messages.minItems"))
    }

    @Test("the limit floors maxLength and clamps it to 0 through 1000", arguments: [(2.5, 2), (-5, 0), (1e300, 1000)])
    func limit(maxLength: Double, max: Int) throws {
        let definition = attachments("1.7", validation: ["maxLength": .number(maxLength)])
        let references = (0...max).map { JSONValue.string("upload-\($0)") }
        let over: JSONObject = ["docs": .array(references)]
        let fits: JSONObject = ["docs": .array(Array(references.prefix(max)))]
        let message = "At most \(max) allowed"
        #expect(try FormEngine(definition: definition, values: over).validate()["docs"] == message)
        #expect(try validateSubmission(definition, .object(over)).errors["docs"] == message)
        #expect(try FormEngine(definition: definition, values: fits).validate().isEmpty)
        #expect(try validateSubmission(definition, .object(fits)).errors.isEmpty)
    }

    @Test(
        "the engine fails numbers and objects without a name, and skips empty entries",
        arguments: entryCases)
    func entries(value: JSONValue, error: String?) throws {
        let definition = attachments("1.7", validation: ["required": true, "maxLength": 3])
        #expect(try FormEngine(definition: definition, values: ["docs": value]).validate()["docs"] == error)
    }

    @Test("validators receive the list")
    func validators() throws {
        let engine = FormEngine(
            definition: try FormDefinition(json: attachments("1.7", validation: ["validator": "count"])), values: ["docs": "upload-1"],
            options: FormEngineOptions(validators: ["count": { value, _ in value == ["upload-1"] ? nil : "not a list" }]))
        #expect(engine.validate().isEmpty)
    }
}
