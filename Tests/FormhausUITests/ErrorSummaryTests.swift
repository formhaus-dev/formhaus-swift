import Testing

@testable import FormhausUI

@Suite("Error summary lines")
struct ErrorSummaryTests {
    @Test("a label without closing punctuation gets a colon")
    func plainLabel() {
        #expect(summaryLine("Email", "Enter a valid email") == "Email: Enter a valid email")
        #expect(summaryLine("Name)", "Required") == "Name): Required")
        #expect(summaryLine("", "Required") == ": Required")
    }

    @Test(
        "a label that ends with punctuation gets a space",
        arguments: ["?", "!", ":", ".", "\u{FF1F}", "\u{FF01}", "\u{FF1A}", "\u{FF0E}", "\u{3002}"])
    func punctuatedLabel(mark: String) {
        #expect(summaryLine("What do you need\(mark)", "Choose one") == "What do you need\(mark) Choose one")
    }

    @Test("only the last character of the label counts")
    func innerPunctuation() {
        #expect(summaryLine("Why? Tell us", "Required") == "Why? Tell us: Required")
    }
}
