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
        "check-image-urls", "check-matrix", "check-matrix-options", "check-missing-required", "check-multiple", "check-multiple-type",
        "check-null-lists", "check-numeric-id", "check-outdated-version-1-0", "check-outdated-version-contains",
        "check-outdated-version-exclusive", "check-outdated-version-missing", "check-outdated-version-multiple",
        "check-outdated-version-newer", "check-outdated-version-randomize", "check-randomize", "check-randomize-type", "check-scale",
        "check-scale-range", "check-section-forward-reference", "check-slow-pattern", "contains-disabled", "contains-limit",
        "disabled-actions", "duplicate-options", "exclusive-options", "file-app-reference", "file-multiple", "file-multiple-items",
        "file-multiple-limits", "flat-api-steps", "format-version", "group-list-answers", "group-over-limit", "hidden-values",
        "i18n-empty-overlay", "i18n-exclusive-branches", "i18n-own-properties", "i18n-renderer-labels", "i18n-signup-steps",
        "impossible-dates", "invalid-labels", "invalid-messages", "locale-precedence", "localized-catalog", "localized-overlay",
        "option-order", "options-from", "proto-keys", "recall-branches", "recall-groups", "recall-inactive", "recall-limit",
        "recall-no-reexpansion", "recall-sensitive", "recall-steps", "recall-syntax", "recall-translations", "recall-values",
        "recall-version", "reveal", "shared-key-branches", "times-and-hidden", "trimmed-conditions", "trimmed-text",
        "unsupported-format-version",
    ]

    static let withWarnings = Corpus.names.filter { Corpus.fixture($0).warnings != nil }
    static let rejected = Corpus.names.filter { !Corpus.fixture($0).issues.isEmpty }
    static let slow = Corpus.names.filter { Corpus.fixture($0).warnings?.contains { $0.code == "slow-pattern" } == true }

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

    @Test("says the server refuses no pattern wherever slow patterns are reported")
    func refusesNone() {
        let listed = Self.slow.filter { Corpus.fixture($0).refused?.isEmpty != true }
        #expect(listed.isEmpty)
    }

    @Test("the server refuses no pattern", arguments: Corpus.names)
    func serverRunsEveryPattern(name: String) {
        var codes: [IssueCode] = []
        do {
            _ = try validateSubmission(Corpus.fixture(name).definition, .object(JSONObject()))
        } catch {
            codes = error.issues.map(\.code)
        }
        #expect(!codes.contains(.slowPattern))
    }
}
