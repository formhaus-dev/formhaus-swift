import Testing
@testable import FormhausCore

@Suite("JavaScript compatibility")
struct JSCompatibilityTests {
    @Test("numbers print like Number.prototype.toString", arguments: [
        (5.0, "5"), (-0.0, "0"), (0.1, "0.1"), (123.456, "123.456"), (1e-7, "1e-7"), (0.000001, "0.000001"),
        (1e21, "1e+21"), (1e20, "100000000000000000000"), (1.5e300, "1.5e+300"), (-2.5, "-2.5"),
    ])
    func numberStrings(value: Double, text: String) {
        #expect(jsNumberString(value) == text)
    }

    @Test("strings convert like Number()")
    func numberParsing() {
        #expect(jsNumber(fromString: " 42 ") == 42)
        #expect(jsNumber(fromString: "5.") == 5)
        #expect(jsNumber(fromString: ".5") == 0.5)
        #expect(jsNumber(fromString: "+1e3") == 1000)
        #expect(jsNumber(fromString: "0x10") == 16)
        #expect(jsNumber(fromString: "-Infinity") == -.infinity)
        #expect(jsNumber(fromString: "1_000").isNaN)
        #expect(jsNumber(fromString: "-0x10").isNaN)
        #expect(jsNumber(fromString: "abc").isNaN)
    }

    @Test("trim removes JavaScript whitespace only")
    func trimming() {
        #expect("\u{FEFF}\u{A0} a \u{2028}".jsTrimmed == "a")
        #expect("\u{200B}a".jsTrimmed == "\u{200B}a")
    }

    @Test("patterns follow ECMAScript semantics")
    func patterns() throws {
        #expect(try #require(JSRegex("^\\d+$")).test("123"))
        #expect(!(try #require(JSRegex("^\\d+$")).test("123\n")))
        #expect(!(try #require(JSRegex("^\\d$")).test("\u{663}")))
        #expect(!(try #require(JSRegex("^\\w$")).test("é")))
        #expect(try #require(JSRegex("^a{$")).test("a{"))
        #expect(try #require(JSRegex("^[^]$")).test("\n"))
        #expect(!(try #require(JSRegex("^.$")).test("\n")))
        #expect(try #require(JSRegex("^\\a$")).test("a"))
        #expect(try #require(JSRegex("[(a+)]+")).test("+"))
        #expect(JSRegex("[invalid(") == nil)
        #expect(JSRegex("(a") == nil)
    }

    @Test("parser keeps key order and own __proto__ keys")
    func parser() throws {
        let value = try JSONValue(parsing: #"{"b":1,"__proto__":{"x":true},"a":[null,"é😀"]}"#)
        let object = try #require(value.objectValue)
        #expect(object.keys == ["b", "__proto__", "a"])
        #expect(object["a"] == .array([.null, .string("é😀")]))
        #expect(throws: JSONParseError.self) { try JSONValue(parsing: "{\"a\":01}") }
    }
}
