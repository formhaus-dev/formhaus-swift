import Testing
import FormhausCore

@Suite("Public API surface")
struct APISurfaceTests {
    static let definition: JSONValue = [
        "id": "f", "title": "F", "submit": ["label": "S"],
        "steps": [
            [
                "id": "one", "title": "One",
                "fields": [["key": "a", "type": "text", "label": "A", "validation": ["required": true]]],
                "routes": [["to": nil, "show": [["field": "a", "eq": "end"]]]],
            ],
            [
                "id": "two", "title": "Two", "show": [["field": "a", "neq": "skip"]],
                "fields": [["key": "s", "type": "section", "title": "S", "showAny": [["field": "a", "eq": "x"]], "fields": []]],
            ],
        ],
    ]

    @Test("isVisible accepts steps, routes, sections and nodes")
    func visibilityOfAnyNode() throws {
        let form = try FormDefinition(json: Self.definition)
        let steps = try #require(form.steps)
        #expect(isVisible(steps[1], ["a": "x"]))
        #expect(!isVisible(steps[1], ["a": "skip"]))
        #expect(isVisible(try #require(steps[0].routes?.first), ["a": "end"]))
        let section = try #require(steps[1].fields.first)
        #expect(isVisible(section, ["a": "x"]))
        #expect(!isVisible(try #require(section.section), ["a": "y"]))
    }

    @Test("issue codes and message keys are open string sets")
    func openCodes() {
        #expect(IssueCode.invalidType.rawValue == "invalid-type")
        #expect(IssueCode(rawValue: "future-code") == "future-code")
        #expect(MessageKey.minLength == MessageKey(rawValue: "minLength"))
        #expect(MessageKey(rawValue: "caf\u{E9}") != MessageKey(rawValue: "cafe\u{301}"))
        #expect(checkDefinition(["id": "f", "submit": ["label": "S"], "fields": 1]).map(\.code).contains(.invalidType))
        #expect(getDefaultMessage(.min, ["min": 2]) == "Must be at least 2")
    }

    @Test("message functions receive message keys")
    func messageFunctions() throws {
        let options = SubmissionOptions(messages: .function { key, _, field in key == .required ? "Need \(field.key)" : nil })
        let result = try validateSubmission(Self.definition, [:], options: options)
        #expect(result.errors == ["a": "Need a"])
    }

    @Test("checks, submissions and slots run from any thread")
    func nonisolatedFunctions() async throws {
        let definition = Self.definition
        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    let issues = checkDefinition(definition).filter(\.isError)
                    let errors = (try? validateSubmission(definition, ["a": "x"]))?.errors.count ?? -1
                    let slots = (try? FormDefinition(json: definition)).map { textSlots($0).count } ?? -1
                    let localized = (try? localize(definition, overlay: ["title": "T"]))?.definition.title == "T"
                    return issues.count + errors + (slots > 0 ? 0 : 100) + (localized ? 0 : 1000)
                }
            }
            var all: [Int] = []
            for await value in group { all.append(value) }
            return all
        }
        #expect(results == Array(repeating: 0, count: 16))
    }

    @Test("the engine runs on the main actor")
    @MainActor func mainActorEngine() throws {
        let engine = try FormEngine(definition: Self.definition, values: ["a": "x"])
        #expect(engine.isMultiStep)
        #expect(engine.currentStep?.id == "one")
        #expect(engine.validate().isEmpty)
        #expect(FormDefinition.supportedFormatVersion == "1.2")
    }
}
