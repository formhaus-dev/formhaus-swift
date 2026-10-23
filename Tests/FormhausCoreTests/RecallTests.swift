import Testing

@_spi(Renderer) @testable import FormhausCore

private func field(_ type: String) throws -> FormField {
    try #require(FormDefinition(unchecked: ["id": "f", "fields": [["key": "a", "type": .string(type), "label": "A"]]]).allFields.first)
}

private func formatted(_ answer: RecallAnswer, _ type: String, _ locale: String = "en") throws -> String {
    defaultRecallFormat(answer, try field(type), locale)
}

@Suite("Answer recall")
struct RecallTests {
    @Test("the default formatter uses the platform styles in UTC")
    func defaultStyles() throws {
        #expect(try formatted(.text("2027-06-14"), "date") == "Jun 14, 2027")
        #expect(try formatted(.text("13:05"), "time").hasPrefix("1:05"))
        #expect(try formatted(.text("2027-06-14T13:05+09:00"), "datetime").hasPrefix("Jun 14, 2027"))
        #expect(try formatted(.number(1234.5), "number") == "1,234.5")
        #expect(try formatted(.number(0.1), "number") == "0.1")
        #expect(try formatted(.number(-0.0), "scale") == "0")
        #expect(try formatted(.number(3), "group") == "3")
        #expect(try formatted(.list(["Red", "Green", "Blue"]), "multiselect") == "Red, Green, and Blue")
        #expect(try formatted(.number(1234.5), "number", "de") == "1.234,5")
        #expect(try formatted(.text("2027-06-14"), "date", "de").contains("2027"))
    }

    @Test("the default formatter falls back to the stored text and to en")
    func fallbacks() throws {
        #expect(try formatted(.text("2027-02-30"), "date") == "2027-02-30")
        #expect(try formatted(.number(1e21), "number") == "1e+21")
        #expect(try formatted(.number(1234.5), "text") == "1234.5")
        #expect(try formatted(.text("a \n\t b"), "text") == "a b")
        #expect(try formatted(.number(1234.5), "number", "not a locale!") == "1,234.5")
        #expect(try formatted(.number(1234.5), "number", "zz") == "1,234.5")
        #expect(try formatted(.number(1234.5), "number", "") == "1,234.5")
    }

    @Test("item titles and error labels resolve recall in one pass with their parameters")
    @MainActor func itemTitles() throws {
        let engine = try FormEngine(
            definition: [
                "formatVersion": "1.5", "id": "f", "title": "Form for {{host}}", "submit": ["label": "S"],
                "fields": [
                    ["key": "host", "type": "text", "label": "Host"],
                    [
                        "key": "people", "type": "group", "label": "Guests of {{host}}", "itemLabel": "{{name}} #{index} of {label}",
                        "fields": [["key": "name", "type": "text", "label": "Name of {{name}}", "validation": ["required": true]]],
                    ],
                ],
            ], values: ["host": "{index}", "people": [["name": "Bo"], [:]]])
        let group = try #require(engine.definition.allFields.last)
        #expect(engine.itemTitle(group, 0, nil) == "Bo #1 of Guests of {index}")
        engine.validate()
        let errors = errorSummary(engine).groups
        #expect(errors.first?.title == "Form for {index}")
        #expect(errors.first?.entries.first?.label == "Name of  ( #2 of Guests of {index})")
    }
}
