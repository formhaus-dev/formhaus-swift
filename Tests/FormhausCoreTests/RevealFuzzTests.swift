import Foundation
import Testing

@testable import FormhausCore

@Suite("Revealed fields against @formhaus/core")
struct RevealFuzzTests {
    static let path = ProcessInfo.processInfo.environment["FORMHAUS_REVEAL_FUZZ"]

    @Test("matches revealTargets on generated definitions", .enabled(if: path != nil, "runs with scripts/reveal-fuzz.sh"))
    func generated() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: try #require(Self.path)))
        var cases = 0
        var mismatches = 0
        var samples: [String] = []
        for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            let entry = try JSONValue(parsing: Data(line))
            let definition = entry["definition"] ?? .null
            cases += 1
            guard revealPointers(definition) != entry["reveals"] else { continue }
            mismatches += 1
            if samples.count < 5 { samples.append(String(bytes: line, encoding: .utf8) ?? "") }
        }
        print("reveal fuzz: \(cases) definitions, \(mismatches) mismatches")
        #expect(cases > 0)
        #expect(mismatches == 0, "\(samples.joined(separator: "\n"))")
    }
}
