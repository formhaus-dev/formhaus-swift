import Testing

@testable import FormhausCore

@Suite("Conformance corpus: answer recall")
struct CorpusRecallTests {
    static let recallNames = Corpus.names.flatMap { name in Corpus.fixture(name).recall.map { "\(name): \($0.name)" } }

    private func recallCase(_ id: String) throws -> (CorpusFixture, RecallCase) {
        let separator = try #require(id.range(of: ": "))
        let fixture = Corpus.fixture(String(id[..<separator.lowerBound]))
        let matches = fixture.recall.filter { sameUnits($0.name, String(id[separator.upperBound...])) }
        try #require(matches.count == 1, "\(matches.count) recall cases named \(id)")
        return (fixture, matches[0])
    }

    @Test("recall case names are unique in every fixture", arguments: Corpus.names)
    func uniqueNames(name: String) {
        #expect(duplicates(Corpus.fixture(name).recall.map(\.name)).isEmpty)
    }

    @Test("recall", arguments: recallNames)
    @MainActor func recall(id: String) throws {
        try check(id, .clear)
    }

    @Test("recall reads kept hidden values as unanswered", arguments: recallNames)
    @MainActor func keptRecall(id: String) throws {
        try check(id, .keep)
    }

    @MainActor private func check(_ id: String, _ hiddenValues: HiddenValues) throws {
        let (fixture, testCase) = try recallCase(id)
        let definition = try fixture.runtime()
        let slots = textSlots(definition)
        let options = FormEngineOptions(onWarning: { _ in }, hiddenValues: hiddenValues)
        let engine = FormEngine(definition: definition, values: testCase.values, options: options)
        for entry in testCase.texts {
            let slot = try #require(slots.first { sameUnits($0.address, entry.address) }, "\(entry.address)")
            let text = engine.recallText(slot.text, options: RecallOptions(item: entry.item, format: storedRecallFormat))
            #expect(sameUnits(text, entry.text), "\(entry.address) \(entry.item.map { "\($0.index)" } ?? "")")
        }
    }
}
