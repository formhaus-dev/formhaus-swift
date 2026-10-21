import Testing

@testable import FormhausCore
@testable import FormhausResearch

@Suite("Conformance corpus: option order")
struct OptionOrderTests {
    static let vectors: [String] = Corpus.names.flatMap { name in Corpus.orders(name).indices.map { "\(name): \($0)" } }

    @Test("vectors", arguments: vectors)
    func vector(id: String) throws {
        let separator = try #require(id.range(of: ": "))
        let index = try #require(Int(id[separator.upperBound...]))
        let vector = Corpus.orders(String(id[..<separator.lowerBound]))[index]
        let seed = try #require(vector["seed"]?.units)
        let key = try #require(vector["key"]?.units)
        let count = Int(vector["count"]?.number ?? 0)
        let pinned = Set((vector["pinned"]?.items ?? []).compactMap { $0.number.map(Int.init) })
        let expected = (vector["order"]?.items ?? []).compactMap { $0.number.map(Int.init) }
        #expect(optionOrder(seed: seed, key: key, pinned: (0..<count).map(pinned.contains)) == expected)
    }

    @Test("the vectors keep the code units of a lone surrogate seed")
    func loneSurrogateSeed() {
        #expect(Corpus.orders("option-order").contains { $0["seed"]?.units == [0xD800] })
    }

    @Test("option warnings come in option order")
    func optionWarningOrder() {
        let definition: JSONValue = [
            "formatVersion": "1.6", "id": "f", "title": "F", "submit": ["label": "S"],
            "fields": [
                [
                    "key": "plan", "type": "radio", "label": "Plan",
                    "options": [
                        ["value": "a", "label": "A", "pinned": true], ["value": "b", "label": "B", "image": "http://example.com/b.png"],
                    ],
                ]
            ],
        ]
        let codes: [IssueCode] = [.randomizeNotApplicable, .unsafeImageUrl]
        let issues = checkDefinition(definition).filter { codes.contains($0.code) }.map(\.path)
        #expect(issues == ["/fields/0/options/0/pinned", "/fields/0/options/1/image"])
    }

    @Test("the research order keeps pinned and exclusive options in place")
    func research() {
        let options = (0..<6).map { index -> FieldOption in
            var json: JSONObject = ["value": .string("o\(index)"), "label": "O"]
            if index == 0 { json["pinned"] = true }
            if index == 5 { json["exclusive"] = true }
            return FieldOption(json: json)
        }
        let order = Research().order(seed: "seed", key: "plan", options: options).compactMap(\.value)
        let pinned = [true, false, false, false, false, true]
        #expect(order == optionOrder(seed: "seed".utf16, key: "plan".utf16, pinned: pinned).map { "o\($0)" })
        #expect(order.first == "o0" && order.last == "o5")
        #expect(Research().seed().count == 32)
        #expect(Research().seed() != Research().seed())
    }

    @Test("the engine takes its seed from the option, then from research, and keeps written order without research")
    @MainActor func engineSeed() throws {
        let definition: JSONValue = [
            "formatVersion": "1.6", "id": "f", "submit": ["label": "S"],
            "fields": [
                [
                    "key": "plan", "type": "radio", "label": "Plan", "randomize": true,
                    "options": .array((0..<8).map { ["value": .string("p\($0)"), "label": "P"] }),
                ]
            ],
        ]
        let written = (0..<8).map { "p\($0)" }
        let plain = try FormEngine(definition: definition, options: FormEngineOptions(seed: "fixed"))
        #expect(plain.seed == "fixed")
        #expect(plain.orderOptions("plan").compactMap(\.value) == written)
        let seeded = try FormEngine(definition: definition, options: FormEngineOptions(seed: "fixed", research: Research()))
        let again = try FormEngine(definition: definition, options: FormEngineOptions(seed: "fixed", research: Research()))
        #expect(seeded.orderOptions("plan").compactMap(\.value) == again.orderOptions("plan").compactMap(\.value))
        #expect(Set(seeded.orderOptions("plan").compactMap(\.value)) == Set(written))
        let random = try FormEngine(definition: definition, options: FormEngineOptions(seed: "", research: Research()))
        #expect(random.seed.count == 32)
    }
}
