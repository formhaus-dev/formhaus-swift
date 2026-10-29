import Testing

@testable import FormhausCore

@Suite("Conformance corpus: texts and cases")
struct CorpusCaseTests {
    static let withTexts = Corpus.names.filter { Corpus.fixture($0).texts != nil }

    @MainActor private func browserEngine(_ definition: FormDefinition, _ fixture: CorpusFixture, _ testCase: CorpusCase) -> FormEngine {
        FormEngine(
            definition: definition, values: testCase.values.objectValue ?? JSONObject(),
            options: FormEngineOptions(locale: fixture.locale, hiddenValues: testCase.hiddenValues))
    }

    private func serverResult(_ definition: FormDefinition, _ fixture: CorpusFixture, _ testCase: CorpusCase) throws -> SubmissionResult {
        let catalogs = localeMessages(fixture.locale)
        let messages = catalogs.map { _ in MessageSource.function(messageResolver(.catalog(definition.messages ?? .null), catalogs)) }
        let options = SubmissionOptions(skippedSteps: testCase.skippedSteps, messages: messages, hiddenValues: testCase.hiddenValues)
        return try validateSubmission(definition, testCase.values, options: options)
    }

    @MainActor private func browserCanSubmit(
        _ definition: FormDefinition, _ fixture: CorpusFixture, _ testCase: CorpusCase
    ) async throws -> Bool {
        let engine = browserEngine(definition, fixture, testCase)
        while engine.isMultiStep && !engine.isLastStep {
            if engine.isActionDisabled(engine.currentStep?.next.action) { return false }
            if try await !engine.next() { return false }
        }
        return engine.validate().isEmpty && !engine.isActionDisabled(definition.submit)
    }

    @Test("case names are unique in every fixture", arguments: Corpus.names)
    func uniqueCaseNames(name: String) {
        #expect(duplicates(Corpus.fixture(name).cases.map(\.name)).isEmpty)
    }

    @Test("texts", arguments: withTexts)
    func texts(name: String) throws {
        let fixture = Corpus.fixture(name)
        let unchecked = fixture.issues.isEmpty ? nil : fixture.definition.objectValue.map(FormDefinition.init(unchecked:))
        let slots = try textSlots(unchecked ?? fixture.runtime())
        #expect(duplicates(slots.map(\.address)).isEmpty, "duplicate text slot addresses")
        for (address, text) in fixture.texts ?? JSONObject() {
            let found = slots.filter { sameUnits($0.address, address) }.map { JSONValue.string($0.text) }
            #expect(strictlyEqual(found.first ?? .null, text), "\(address)")
        }
    }

    @Test("server", arguments: Corpus.caseNames)
    func server(id: String) throws {
        let (fixture, testCase) = try Corpus.testCase(id)
        let result = try serverResult(try fixture.runtime(), fixture, testCase)
        #expect(strictlyEqual(.object(result.values), testCase.serverValues ?? testCase.expectedValues))
        #expect(strictlyEqual(json(result.errors), testCase.expectedErrors))
    }

    @Test("browser engine", arguments: Corpus.caseNames)
    @MainActor func browserEngine(id: String) async throws {
        let (fixture, testCase) = try Corpus.testCase(id)
        let definition = try fixture.runtime()
        let engine = browserEngine(definition, fixture, testCase)
        #expect(strictlyEqual(json(engine.validate()), testCase.expectedErrors))
        #expect(strictlyEqual(.object(engine.getSubmitValues()), testCase.expectedValues))
        #expect(try await browserCanSubmit(definition, fixture, testCase) == testCase.canSubmit)
    }

    @Test("a payload the browser accepts passes the server", arguments: Corpus.caseNames)
    @MainActor func acceptedPayloadPassesServer(id: String) async throws {
        let (fixture, testCase) = try Corpus.testCase(id)
        let definition = try fixture.runtime()
        guard try await browserCanSubmit(definition, fixture, testCase) else { return }
        #expect(try serverResult(definition, fixture, testCase).errors.isEmpty)
    }

    @Test("strict comparison separates -0, NFC and NFD")
    func strictComparison() {
        #expect(!strictlyEqual(.number(-0.0), .number(0)))
        #expect(strictlyEqual(.number(.nan), .number(.nan)))
        #expect(!strictlyEqual(.string("caf\u{E9}"), .string("cafe\u{301}")))
        #expect(!strictlyEqual(["caf\u{E9}": 1], ["cafe\u{301}": 1]))
        #expect(strictlyEqual(["a": 1, "b": [true, nil]], ["b": [true, nil], "a": 1]))
        #expect(!strictlyEqual(["a": 1], ["a": "1"]))
        #expect(duplicates(["a", "b", "a"]) == ["a"])
    }
}
