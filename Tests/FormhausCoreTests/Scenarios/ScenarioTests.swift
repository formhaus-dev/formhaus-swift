import FormhausCore
import Testing

@Suite("Engine scenarios")
struct ScenarioTests {
    @Test("scenario names are unique in every file", arguments: Scenarios.files.map(\.name))
    func uniqueNames(name: String) throws {
        let file = try #require(Scenarios.files.first { $0.name == name })
        let names = file.scenarios.map { $0["name"]?.stringValue ?? "" }
        #expect(duplicates(names) == [])
    }

    @Test("uses each defer name once per scenario", arguments: Scenarios.files.map(\.name))
    func uniqueDeferNames(name: String) throws {
        let file = try #require(Scenarios.files.first { $0.name == name })
        let repeated = file.scenarios.filter { scenario in
            let names = deferNames(scenario["hooks"]) + deferNames(scenario["steps"])
            return names.count != Set(names).count
        }
        #expect(repeated.map { $0["name"]?.stringValue ?? "" } == [])
    }

    @Test("scenario", arguments: Scenarios.ids)
    @MainActor func scenario(id: String) async throws {
        let (file, scenario) = try Scenarios.lookup(id)
        if let name = scenario["throws"]?.stringValue {
            let values = scenario["values"]?.objectValue ?? JSONObject()
            let error = #expect(throws: (any Error).self) { _ = FormEngine(definition: try file.runtime(scenario), values: values) }
            let projected = error.map { errorProjection($0, [:]) }
            #expect(projected?["name"] == .string(name))
            return
        }
        let failures = try await ScenarioRun(file, scenario).run()
        let report = failures.joined(separator: "\n")
        #expect(report.isEmpty, "\(report)")
    }
}

private func deferNames(_ value: JSONValue?) -> [String] {
    switch value {
    case .array(let items)?: items.flatMap(deferNames)
    case .object(let object)?:
        object.flatMap { key, item in
            guard key == "defer", let name = item.stringValue else { return deferNames(item) }
            return [name]
        }
    default: []
    }
}
