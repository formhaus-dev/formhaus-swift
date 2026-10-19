import Testing
import FormhausCore

@Suite("Conformance scenarios")
struct ScenarioFileTests {
    static let directory = Corpus.directory.appendingPathComponent("scenarios")
    static let files = Corpus.jsonFiles(in: directory).filter { $0 != "scenario.schema" }

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
