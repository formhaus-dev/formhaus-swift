import Foundation

struct JSRegex: @unchecked Sendable {
    private let expression: NSRegularExpression

    init?(_ source: String) {
        guard let translated = translatePattern(source),
            let expression = try? NSRegularExpression(pattern: translated)
        else { return nil }
        self.expression = expression
    }

    func test(_ text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return expression.firstMatch(in: text, options: [], range: range) != nil
    }
}

private let space = "\\t\\n\\x{0B}\\f\\r \\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}"
private let word = "A-Za-z0-9_"
private let lineTerminators = "\\n\\r\\x{2028}\\x{2029}"

private func classEscape(_ letter: Character, inClass: Bool) -> String? {
    switch letter {
    case "d": return inClass ? "0-9" : "[0-9]"
    case "D": return "[^0-9]"
    case "w": return inClass ? word : "[\(word)]"
    case "W": return "[^\(word)]"
    case "s": return inClass ? space : "[\(space)]"
    case "S": return "[^\(space)]"
    default: return nil
    }
}

private func plainEscape(_ letter: Character, next: Character?, inClass: Bool) -> String {
    switch letter {
    case "n", "r", "t", "f": return "\\\(letter)"
    case "v": return "\\x{0B}"
    case "0" where next.map({ !$0.isASCII || !$0.isNumber }) ?? true: return "\\x{0}"
    case "b" where inClass: return "\\x{08}"
    case "b": return "(?:(?<=[\(word)])(?![\(word)])|(?<![\(word)])(?=[\(word)]))"
    case "B": return "(?:(?<=[\(word)])(?=[\(word)])|(?<![\(word)])(?![\(word)]))"
    default:
        if letter.isASCII && (letter.isLetter || letter.isNumber) { return String(letter) }
        return "\\\(letter)"
    }
}

func translatePattern(_ source: String) -> String? {
    let chars = Array(source)
    var output = ""
    var inClass = false
    var classStart = false
    var index = 0
    while index < chars.count {
        let char = chars[index]
        let atClassStart = classStart
        classStart = false
        if char == "\\" {
            guard index + 1 < chars.count else { return nil }
            let letter = chars[index + 1]
            let next = index + 2 < chars.count ? chars[index + 2] : nil
            index += 2
            if let replacement = classEscape(letter, inClass: inClass) {
                output += replacement
            } else if letter == "x" || letter == "u" || letter == "c" {
                output += consumeCodeEscape(letter, chars, &index)
            } else if letter.isASCII && letter.isNumber && letter != "0" {
                output += inClass ? "\\x{\(String(letter.asciiValue! - 0x30, radix: 16))}" : "\\\(letter)"
            } else if letter == "k" {
                output += "\\k"
            } else {
                output += plainEscape(letter, next: next, inClass: inClass)
            }
            continue
        }
        index += 1
        if inClass {
            switch char {
            case "]" where !atClassStart: inClass = false; output += "]"
            case "]": output += "\\]"
            case "[", "&", "~": output += "\\\(char)"
            case "^" where atClassStart: output += "^"; classStart = true
            case "-" where output.hasSuffix("-"): output += "\\-"
            default: output.append(char)
            }
            continue
        }
        switch char {
        case "[":
            if index + 1 < chars.count, chars[index] == "^", chars[index + 1] == "]" {
                index += 2
                output += "(?s:.)"
            } else if index < chars.count, chars[index] == "]" {
                index += 1
                output += "(?!)"
            } else {
                inClass = true
                classStart = true
                output += "["
            }
        case ".": output += "[^\(lineTerminators)]"
        case "$": output += "\\z"
        case "{" where !isQuantifier(chars, from: index): output += "\\{"
        case "}" where !closesQuantifier(chars, before: index - 1): output += "\\}"
        case "]": output += "\\]"
        case "#", " ": output += "\\\(char)"
        default: output.append(char)
        }
    }
    return inClass ? nil : output
}

private func consumeCodeEscape(_ letter: Character, _ chars: [Character], _ index: inout Int) -> String {
    let length = letter == "x" ? 2 : letter == "u" ? 4 : 1
    guard index + length <= chars.count else { return String(letter) }
    let body = String(chars[index..<index + length])
    if letter == "c" {
        guard let ascii = body.first?.asciiValue, body.first!.isLetter else { return "\\\\c" }
        index += 1
        return "\\x{\(String(ascii % 32, radix: 16))}"
    }
    guard let value = UInt32(body, radix: 16), body.allSatisfy(\.isHexDigit) else { return String(letter) }
    index += length
    return "\\x{\(String(value, radix: 16))}"
}

private func isQuantifier(_ chars: [Character], from start: Int) -> Bool {
    var index = start
    var digits = 0
    while index < chars.count, chars[index].isASCII, chars[index].isNumber { index += 1; digits += 1 }
    guard digits > 0, index < chars.count else { return false }
    if chars[index] == "}" { return true }
    guard chars[index] == "," else { return false }
    index += 1
    while index < chars.count, chars[index].isASCII, chars[index].isNumber { index += 1 }
    return index < chars.count && chars[index] == "}"
}

private func closesQuantifier(_ chars: [Character], before end: Int) -> Bool {
    var index = end - 1
    while index >= 0, (chars[index].isASCII && chars[index].isNumber) || chars[index] == "," { index -= 1 }
    return index >= 0 && chars[index] == "{" && isQuantifier(chars, from: index + 1)
}
