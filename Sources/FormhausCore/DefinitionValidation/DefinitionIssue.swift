public struct DefinitionIssue: Sendable, Hashable {
    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public let code: IssueCode
    public let severity: Severity
    public let path: String
    public let message: String
    public let hint: String?

    public var isError: Bool { severity == .error }

    init(_ severity: Severity, _ code: IssueCode, _ path: String, _ problem: String, _ hint: String? = nil) {
        let sentence = hint.map { $0.hasSuffix("?") ? $0 : "\($0)." }
        self.code = code
        self.severity = severity
        self.path = path
        self.hint = sentence
        message = "\(path.isEmpty ? "/" : path): \(problem).\(sentence.map { " \($0)" } ?? "")"
    }

    func withSeverity(_ severity: Severity) -> DefinitionIssue {
        DefinitionIssue(severity: severity, code: code, path: path, message: message, hint: hint)
    }

    private init(severity: Severity, code: IssueCode, path: String, message: String, hint: String?) {
        self.code = code
        self.severity = severity
        self.path = path
        self.message = message
        self.hint = hint
    }
}

public struct FormDefinitionError: Error, Sendable, CustomStringConvertible {
    public let issues: [DefinitionIssue]

    public var description: String {
        "Invalid form definition:\n" + issues.map(\.message).joined(separator: "\n")
    }
}

func error(_ code: IssueCode, _ path: String, _ problem: String, _ hint: String? = nil) -> DefinitionIssue {
    DefinitionIssue(.error, code, path, problem, hint)
}

func warning(_ code: IssueCode, _ path: String, _ problem: String, _ hint: String? = nil) -> DefinitionIssue {
    DefinitionIssue(.warning, code, path, problem, hint)
}

func pointer(_ key: String) -> String {
    key.replacingOccurrences(of: "~", with: "~0", options: .literal).replacingOccurrences(of: "/", with: "~1", options: .literal)
}

func oneOf(_ values: [String]) -> String {
    if values.count == 1 { return "Use \(quoteJSON(values[0]))" }
    let shown = values.prefix(10).map(quoteJSON).joined(separator: ", ")
    return values.count > 10 ? "Use one of: \(shown), ..." : "Use one of: \(shown)"
}

private func distance(_ a: [UInt16], _ b: [UInt16]) -> Int {
    var row = Array(0...b.count)
    guard !a.isEmpty else { return row[b.count] }
    for i in 1...a.count {
        var next = [i]
        if !b.isEmpty {
            for j in 1...b.count {
                next.append(Swift.min(row[j] + 1, next[j - 1] + 1, row[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)))
            }
        }
        row = next
    }
    return row[b.count]
}

func closest(_ value: String, _ candidates: [String]) -> String? {
    let lower = Array(value.lowercased().utf16)
    return candidates.first { candidate in
        !candidate.utf16.elementsEqual(value.utf16)
            && distance(lower, Array(candidate.lowercased().utf16)) <= (candidate.jsLength > 4 ? 2 : 1)
    }
}

func suggest(_ value: String, _ candidates: [String]) -> String? {
    if let match = closest(value, candidates) { return "Use \(quoteJSON(match))" }
    return candidates.isEmpty ? nil : oneOf(candidates)
}
