import os

enum PatternVerdict: Sendable {
    case refused
    case quadratic
    case safe
}

let quadraticValueLength = 1000

private let verdicts = OSAllocatedUnfairLock<[[UInt16]: PatternVerdict]>(initialState: [:])

func patternVerdict(_ pattern: String) -> PatternVerdict {
    let units = Array(pattern.utf16)
    if units.count > slowPatternLengthLimit { return .refused }
    if let cached = verdicts.withLock({ $0[units] }) { return cached }
    let result: PatternVerdict = slowPattern(pattern) == nil ? .safe : isQuadratic(units) ? .quadratic : .refused
    verdicts.withLock { cache in
        if cache.count >= 256 { cache.removeAll() }
        cache[units] = result
    }
    return result
}

struct QuadraticPatterns: Sendable {
    @TaskLocal static var current = QuadraticPatterns()

    private var patterns: [String: [String]] = [:]

    mutating func insert(_ pattern: String) {
        guard !contains(pattern) else { return }
        patterns[pattern, default: []].append(pattern)
    }

    func contains(_ pattern: String) -> Bool {
        patterns[pattern]?.contains { $0.utf16.elementsEqual(pattern.utf16) } == true
    }

    static func valueLimit(_ pattern: String) -> Int {
        current.patterns.isEmpty || !current.contains(pattern) ? maxStringLength : quadraticValueLength
    }
}

func refuseSlowPatterns(_ definition: FormDefinition) throws(FormDefinitionError) -> QuadraticPatterns {
    var quadratic = QuadraticPatterns()
    var issues: [DefinitionIssue] = []
    for entry in CheckContext(definition).entries {
        guard let pattern = entry.field.validation?.pattern else { continue }
        switch patternVerdict(pattern) {
        case .refused:
            issues.append(
                error(
                    .slowPattern, "\(entry.path)/validation/pattern",
                    "the pattern of \"\(entry.field.key)\" can take very long on some values, so the server does not run it",
                    "Rewrite it without nested or overlapping repeats, in 1000 characters or less"))
        case .quadratic: quadratic.insert(pattern)
        case .safe: break
        }
    }
    guard issues.isEmpty else { throw FormDefinitionError(issues: issues) }
    return quadratic
}
