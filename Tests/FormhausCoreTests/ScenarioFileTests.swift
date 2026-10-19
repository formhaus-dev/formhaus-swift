import Testing
import FormhausCore

@Suite("Conformance scenarios")
struct ScenarioFileTests {
    static let directory = Corpus.directory.appendingPathComponent("scenarios")
    static let files = Corpus.jsonFiles(in: directory).filter { $0 != "scenario.schema" }

    static let pendingEngineScenarios = [
        "active-projection", "async-step-validation", "conditions", "defaults", "definition-messages", "engine-validation",
        "field-validation", "form-events", "form-events-visibility", "groups", "hidden-fields", "hidden-visibility",
        "item-defaults", "last-values", "lifecycle", "lifecycle-values", "messages", "reset", "routes", "skip-guards",
        "skip-steps", "spec-rules", "step-consistency", "step-validation", "steps", "submit-edge-cases", "submit-payload",
        "submit-results", "submit-server-errors", "trimming", "type-formats", "visibility",
    ]

    @Test("every scenario file is listed as pending until the engine runner exists")
    func pendingListMatchesFiles() {
        #expect(Self.files == Self.pendingEngineScenarios.sorted())
    }

    @Test("scenario file loads", arguments: files)
    func scenarioFileLoads(name: String) throws {
        let file = Corpus.load(Self.directory.appendingPathComponent("\(name).json"))
        #expect(file["name"]?.stringValue != nil)
        let definition = try #require(file["definition"])
        #expect(definition.objectValue != nil)
        let scenarios = try #require(file["scenarios"]?.arrayValue)
        #expect(!scenarios.isEmpty)
        for scenario in scenarios {
            #expect(scenario["name"]?.stringValue != nil)
            if scenario["throws"] == nil {
                let own = scenario["definition"] ?? definition
                #expect(checkDefinition(own).allSatisfy { !$0.isError }, "\(scenario["name"]?.stringValue ?? "")")
            }
        }
    }
}
