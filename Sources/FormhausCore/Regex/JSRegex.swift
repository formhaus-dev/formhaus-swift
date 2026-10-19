struct JSRegex: Sendable {
    private let pattern: CompiledPattern?

    init?(_ source: String) {
        guard let pattern = PatternCache.shared.pattern(source) else { return nil }
        self.pattern = pattern
    }

    init(unchecked source: String) {
        pattern = PatternCache.shared.pattern(source)
    }

    func test(_ text: String) -> Bool? {
        pattern?.test(text)
    }
}
