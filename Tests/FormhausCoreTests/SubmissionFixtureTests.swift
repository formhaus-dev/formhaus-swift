import Foundation
import Testing

@testable import FormhausCore

private let directory = (Bundle.module.resourceURL ?? Bundle.module.bundleURL).appendingPathComponent("Fixtures/submissions")

private let cases: [String] = Corpus.jsonFiles(in: directory).flatMap { name in
    (fixture(name)["cases"]?.arrayValue ?? []).map { "\(name): \($0["name"]?.stringValue ?? "")" }
}

private func fixture(_ name: String) -> JSONValue {
    Corpus.load(directory.appendingPathComponent("\(name).json"))
}

@Suite("Submission fixtures")
struct SubmissionFixtureTests {
    @Test("validateSubmission", arguments: cases)
    func submission(id: String) throws {
        let parts = id.split(separator: ": ", maxSplits: 1).map(String.init)
        let file = fixture(parts[0])
        let testCase = try #require(file["cases"]?.arrayValue?.first { $0["name"]?.stringValue == parts[1] })
        let input = testCase["input"]?.objectValue ?? JSONObject()
        let options = SubmissionOptions(
            skippedSteps: input["skippedSteps"], hiddenValues: input["hiddenValues"]?.stringValue.flatMap(HiddenValues.init) ?? .clear,
            previousValues: input["previousValues"])
        let result = try validateSubmission(file["definition"] ?? .null, input["values"] ?? .null, options: options)
        #expect(strictlyEqual(.object(result.values), testCase["expected"]?["values"]))
        #expect(strictlyEqual(json(result.errors), testCase["expected"]?["errors"]))
    }
}
