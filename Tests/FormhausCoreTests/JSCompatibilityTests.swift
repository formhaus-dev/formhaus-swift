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
}
