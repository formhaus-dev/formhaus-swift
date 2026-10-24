import FormhausCore
import Testing

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

    @Test("revealTargets maps each node of a list to the option that reveals it")
    func revealedFields() throws {
        let form = try FormDefinition(json: [
            "id": "f", "submit": ["label": "S"],
            "fields": [
                ["key": "a", "type": "radio", "label": "A", "options": [["value": "x", "label": "X"], ["value": "y", "label": "Y"]]],
                ["key": "b", "type": "text", "label": "B", "show": [["field": "a", "eq": "y"]]],
                ["key": "c", "type": "text", "label": "C"],
            ],
        ])
        #expect(revealTargets(try #require(form.fields)) == [nil, RevealTarget(parent: 0, option: 1), nil])
    }

    @Test("conditions, disabled actions and field validation are callable on their own")
    func standaloneChecks() throws {
        let form = try FormDefinition(json: [
            "id": "f", "submit": ["label": "S", "disabled": [["field": "a", "eq": "lock"]]],
            "fields": [["key": "a", "type": "text", "label": "A", "validation": ["required": true]]],
        ])
        let fields = try #require(form.fields)
        let condition = try #require(form.submit.disabled?.first)
        #expect(evaluateCondition(condition, ["a": "lock"]))
        #expect(!evaluateCondition(condition, ["a": "open"]))
        #expect(isActionDisabled(form.submit, ["a": "lock"]))
        #expect(!isActionDisabled(form.cancel, ["a": "lock"]))
        #expect(validateFields(fields, [:]) == ["a": "This field is required"])
        let field = try #require(fields.first?.field)
        #expect(validateFieldValue(field, "x", ["a": "x"]) == nil)
        #expect(validateFieldValue(field, nil, [:]) == "This field is required")
        #expect(try validateSubmission(form, ["a": "lock"]).errors.isEmpty)
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

    @Test("scale, rating, picture options and matrix sections expose their settings")
    func surveyAccessors() throws {
        let form = try FormDefinition(json: [
            "formatVersion": "1.3", "id": "f", "title": "F", "submit": ["label": "S"],
            "fields": [
                ["key": "nps", "type": "scale", "label": "N", "validation": ["min": 0, "max": 10]],
                ["key": "stars", "type": "rating", "label": "R", "validation": ["min": 3]],
                [
                    "key": "pick", "type": "radio", "label": "P", "columns": 2,
                    "options": [["value": "a", "label": "A", "image": "https://example.com/a.png"]],
                ],
                ["key": "grid", "type": "section", "layout": "matrix", "title": "G", "fields": []],
            ],
        ])
        let nodes = try #require(form.fields)
        let nps = try #require(nodes[0].field?.scaleRange)
        let stars = try #require(nodes[1].field?.scaleRange)
        #expect(nps.min == 0 && nps.max == 10)
        #expect(stars.min == 1 && stars.max == 5)
        #expect(nodes[1].field?.isScale == true && nodes[2].field?.scaleRange == nil)
        #expect(nodes[2].field?.columns == 2)
        #expect(nodes[2].field?.options?.first?.image == "https://example.com/a.png")
        #expect(nodes[3].section?.layout == "matrix" && nodes[3].section?.isMatrix == true)
        #expect(IssueCode.invalidScale.rawValue == "invalid-scale")
        #expect(IssueCode.unsafeImageUrl.rawValue == "unsafe-image-url")
        #expect(IssueCode.columnsNotApplicable.rawValue == "columns-not-applicable")
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

    @Test("locale helpers run from any thread")
    func localeHelpers() async {
        #expect(await Task.detached { localeChain("pt_br") }.value == ["pt-BR", "pt", "en"])
        #expect(await Task.detached { checkCatalog(["locale": "x"]).missing.count }.value == 47)
        #expect(await Task.detached { LocaleCatalog.bundled("de")?.locale }.value == "de")
    }

    @Test("the engine runs on the main actor")
    @MainActor func mainActorEngine() throws {
        let engine = try FormEngine(definition: Self.definition, values: ["a": "x"])
        #expect(engine.isMultiStep)
        #expect(engine.currentStep?.id == "one")
        #expect(engine.validate().isEmpty)
        #expect(FormDefinition.supportedFormatVersion == "1.6")
    }

    @Test("subscribers hear every change until they cancel")
    @MainActor func subscribers() async throws {
        let engine = try FormEngine(definition: Self.definition)
        var count = 0
        let cancel = engine.subscribe { count += 1 }
        engine.setValue("a", "x")
        let heard = count
        #expect(heard > 0)
        cancel()
        engine.setValue("a", "y")
        #expect(count == heard)
        #expect(try await engine.next())
        #expect(engine.currentStep?.id == "two")
    }
}
