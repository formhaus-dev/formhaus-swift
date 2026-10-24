import Testing

@testable import FormhausCore

@Suite("Conformance corpus: revealed fields")
struct CorpusRevealTests {
    static let names = Corpus.names.filter { Corpus.fixture($0).reveals != nil }

    @Test("the corpus pins revealed fields")
    func corpusHasReveals() {
        #expect(!Self.names.isEmpty)
    }

    @Test("reveals", arguments: names)
    func reveals(name: String) {
        let fixture = Corpus.fixture(name)
        #expect(revealPointers(fixture.definition) == fixture.reveals)
    }
}
