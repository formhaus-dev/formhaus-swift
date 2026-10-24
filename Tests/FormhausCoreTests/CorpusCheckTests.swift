import FormhausCore
import Testing

@Suite("Conformance corpus: definition checks")
struct CorpusCheckTests {
    static let audited = [
        "check-autocomplete", "check-autocomplete-type", "check-autocomplete-version", "check-clean", "check-columns",
        "check-columns-not-applicable", "check-conditions", "check-container-conditions", "check-container-keys",
        "check-container-nesting", "check-container-scope", "check-container-shape", "check-contains-not-list",
        "check-contains-options", "check-custom-type-names", "check-default-items", "check-disabled-not-applicable",
        "check-escaped-property", "check-exclusive", "check-field-rules", "check-group-item-ceiling", "check-group-scope",
        "check-image-urls", "check-matrix", "check-matrix-options", "check-missing-required", "check-null-lists", "check-numeric-id",
        "check-outdated-version-1-0", "check-outdated-version-contains", "check-outdated-version-exclusive",
        "check-outdated-version-missing", "check-outdated-version-newer", "check-outdated-version-randomize",
        "check-randomize", "check-randomize-type", "check-scale", "check-scale-range",
        "check-section-forward-reference", "check-slow-pattern", "contains-disabled", "contains-limit", "disabled-actions",
        "duplicate-options", "exclusive-options", "file-app-reference", "flat-api-steps", "format-version", "group-list-answers",
        "group-over-limit", "hidden-values", "i18n-empty-overlay", "i18n-exclusive-branches", "i18n-own-properties", "i18n-renderer-labels",
        "i18n-signup-steps",
        "impossible-dates", "invalid-labels", "invalid-messages", "localized-catalog", "localized-overlay", "option-order", "options-from",
        "proto-keys", "recall-branches", "recall-groups", "recall-inactive", "recall-limit", "recall-no-reexpansion",
        "recall-sensitive", "recall-steps", "recall-syntax", "recall-translations", "recall-values", "recall-version", "reveal",
        "shared-key-branches", "slow-pattern-quadratic", "times-and-hidden", "trimmed-conditions", "trimmed-text",
        "unsupported-format-version",
    ]

    static let withWarnings = Corpus.names.filter { Corpus.fixture($0).warnings != nil }
    static let rejected = Corpus.names.filter { !Corpus.fixture($0).issues.isEmpty }
    static let slow = Corpus.names.filter { Corpus.fixture($0).warnings?.contains { $0.code == "slow-pattern" } == true }
    static let withRefused = Corpus.names.filter { Corpus.fixture($0).refused != nil }

    private func entries(_ issues: [DefinitionIssue], _ severity: DefinitionIssue.Severity) -> [IssueEntry] {
        IssueEntry.sorted(issues.filter { $0.severity == severity }.map { IssueEntry(code: $0.code.rawValue, path: $0.path) })
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
    @MainActor func rejectedByEngineAndServer(name: String) {
        let fixture = Corpus.fixture(name)
        #expect(throws: FormDefinitionError.self) { try FormEngine(definition: fixture.definition) }
        #expect(throws: FormDefinitionError.self) { try validateSubmission(fixture.definition, .object(JSONObject())) }
    }

    @Test("lists the patterns the server refuses wherever slow patterns are reported")
    func refusedListed() {
        #expect(Self.slow.filter { Corpus.fixture($0).refused == nil }.isEmpty)
        #expect(!Self.withRefused.isEmpty)
    }

    @Test("slow patterns refused by the server", arguments: withRefused)
    func refusedByServer(name: String) {
        let fixture = Corpus.fixture(name)
        var issues: [IssueEntry] = []
        do {
            _ = try validateSubmission(fixture.definition, .object(JSONObject()))
        } catch {
            issues = error.issues.map { IssueEntry(code: $0.code.rawValue, path: $0.path) }
        }
        #expect(IssueEntry.sorted(issues) == IssueEntry.sorted(fixture.refused ?? []))
    }
}
