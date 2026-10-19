import Testing
@testable import FormhausCore

@Suite("Conformance corpus: texts and cases")
struct CorpusCaseTests {
    static let withTexts = Corpus.names.filter { Corpus.fixture($0).texts != nil }

    @MainActor private func browserCanSubmit(_ definition: FormDefinition, _ values: JSONObject) -> Bool {
        let engine = FormEngine(definition: definition, values: values)
        while engine.isMultiStep && !engine.isLastStep {
            if isActionDisabled(engine.currentStep?.next.action, engine.getSubmitValues()) || !engine.next() { return false }
        }
        return engine.validate().isEmpty && !isActionDisabled(definition.submit, engine.getSubmitValues())
    }

    @Test("texts", arguments: withTexts)
    func texts(name: String) throws {
        let fixture = Corpus.fixture(name)
        let slots = Dictionary(try textSlots(fixture.runtime()).map { ($0.address, $0.text) }) { first, _ in first }
        for (address, text) in fixture.texts ?? JSONObject() {
            #expect(slots[address].map(JSONValue.string) ?? .null == text, "\(address)")
        }
    }

    @Test("server", arguments: Corpus.caseNames)
    func server(id: String) throws {
        let (fixture, testCase) = Corpus.testCase(id)
        let options = SubmissionOptions(skippedSteps: testCase.skippedSteps)
        let result = validateSubmission(try fixture.runtime(), testCase.values, options: options)
        #expect(result.values == testCase.expectedValues)
        #expect(result.errors == testCase.expectedErrors)
    }

    @Test("browser engine", arguments: Corpus.caseNames)
    @MainActor func browserEngine(id: String) throws {
        let (fixture, testCase) = Corpus.testCase(id)
        let definition = try fixture.runtime()
        let values = testCase.values.objectValue ?? JSONObject()
        let engine = FormEngine(definition: definition, values: values)
        #expect(engine.validate() == testCase.expectedErrors)
        #expect(engine.getSubmitValues() == testCase.expectedValues)
        #expect(browserCanSubmit(definition, values) == testCase.canSubmit)
    }

    @Test("a payload the browser accepts passes the server", arguments: Corpus.caseNames)
    @MainActor func acceptedPayloadPassesServer(id: String) throws {
        let (fixture, testCase) = Corpus.testCase(id)
        let definition = try fixture.runtime()
        guard browserCanSubmit(definition, testCase.values.objectValue ?? JSONObject()) else { return }
        let options = SubmissionOptions(skippedSteps: testCase.skippedSteps)
        #expect(validateSubmission(definition, testCase.values, options: options).errors.isEmpty)
    }
}
