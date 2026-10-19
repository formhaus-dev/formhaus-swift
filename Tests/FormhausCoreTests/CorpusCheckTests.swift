import Testing
import FormhausCore

@Suite("Conformance corpus: definition checks")
struct CorpusCheckTests {
    static let audited = [
        "check-clean", "check-conditions", "check-container-conditions", "check-container-keys", "check-container-nesting",
        "check-container-scope", "check-container-shape", "check-custom-type-names", "check-disabled-not-applicable",
        "check-escaped-property", "check-field-rules", "check-group-scope", "check-missing-required", "check-null-lists",
        "check-numeric-id", "check-outdated-version-1-0", "check-outdated-version-missing", "check-outdated-version-newer",
        "check-section-forward-reference", "check-slow-pattern", "disabled-actions", "flat-api-steps", "format-version",
        "i18n-empty-overlay", "i18n-exclusive-branches", "i18n-own-properties", "i18n-signup-steps", "impossible-dates",
        "invalid-labels", "invalid-messages", "localized-catalog", "localized-overlay", "options-from", "proto-keys",
        "shared-key-branches", "times-and-hidden", "trimmed-conditions", "trimmed-text", "unsupported-format-version",
    ]

    static let withWarnings = Corpus.names.filter { Corpus.fixture($0).warnings != nil }
    static let rejected = Corpus.names.filter { !Corpus.fixture($0).issues.isEmpty }

    private func entries(_ issues: [DefinitionIssue], _ severity: DefinitionIssue.Severity) -> [IssueEntry] {
        IssueEntry.sorted(issues.filter { $0.severity == severity }.map { IssueEntry(code: $0.code, path: $0.path) })
    }

    @Test("covers every audited case")
    func coversEveryAuditedCase() {
        #expect(Corpus.names == Self.audited)
    }

    @Test("checkDefinition", arguments: Corpus.names)
    func checkDefinitionErrors(name: String) {
        let fixture = Corpus.fixture(name)
        #expect(entries(checkDefinition(fixture.definition), .error) == IssueEntry.sorted(fixture.issues))
    }

    @Test("warnings", arguments: withWarnings)
    func checkDefinitionWarnings(name: String) {
        let fixture = Corpus.fixture(name)
        #expect(entries(checkDefinition(fixture.definition), .warning) == IssueEntry.sorted(fixture.warnings ?? []))
    }

    @Test("rejected by the engine and the server", arguments: rejected)
    func rejectedByEngineAndServer(name: String) {
        let fixture = Corpus.fixture(name)
        #expect(throws: FormDefinitionError.self) { try FormEngine(definition: fixture.definition) }
        #expect(throws: FormDefinitionError.self) { try validateSubmission(fixture.definition, .object(JSONObject())) }
    }
}
