import Foundation

extension Character {
    var isASCIILetter: Bool { isASCII && isLetter }
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIIAlphanumeric: Bool { isASCIILetter || isASCIIDigit }
}

struct LanguageTag {
    let parts: [String]
    let extensions: [Substring]
}

private func isVariant(_ text: Substring) -> Bool {
    text.allSatisfy(\.isASCIIAlphanumeric) && ((5...8).contains(text.count) || (text.count == 4 && text.first?.isASCIIDigit == true))
}

private func languageAlias(_ language: String) -> String {
    let mapped = Locale(identifier: language).identifier(.bcp47)
    return (2...8).contains(mapped.count) && mapped.allSatisfy(\.isASCIILetter) ? mapped : language
}

func canonicalTag(_ tag: String) -> LanguageTag? {
    let subtags = tag.prefix { $0 != "@" }.split(separator: "-", omittingEmptySubsequences: false)
    let cut = subtags.indices.dropFirst().first { subtags[$0].count == 1 } ?? subtags.count
    guard let language = subtags.first, [2, 3, 5, 6, 7, 8].contains(language.count), language.allSatisfy(\.isASCIILetter) else {
        return nil
    }
    var rest = subtags[1..<cut]
    var parts = [languageAlias(language.lowercased())]
    if let script = rest.first, script.count == 4, script.allSatisfy(\.isASCIILetter) {
        parts.append(script.prefix(1).uppercased() + script.dropFirst().lowercased())
        rest = rest.dropFirst()
    }
    if let region = rest.first,
        region.count == 2 ? region.allSatisfy(\.isASCIILetter) : region.count == 3 && region.allSatisfy(\.isASCIIDigit)
    {
        parts.append(region.uppercased())
        rest = rest.dropFirst()
    }
    let variants = rest.map { $0.lowercased() }
    guard rest.allSatisfy(isVariant), Set(variants).count == variants.count else { return nil }
    return LanguageTag(parts: parts + variants.sorted(), extensions: Array(subtags[cut...]))
}

public func localeChain(_ tag: String) -> [String] {
    var chain: [String] = []
    if let parts = canonicalTag(tag.replacingOccurrences(of: "_", with: "-"))?.parts {
        chain = parts.indices.reversed().map { parts[...$0].joined(separator: "-") }
        let likely = Locale.Language(identifier: Locale.Language(identifier: chain[0]).maximalIdentifier)
        if let language = likely.languageCode?.identifier, let region = likely.region?.identifier {
            chain.insert("\(language)-\(region)", at: max(chain.count - 1, 1))
        }
    }
    var seen = KeySet()
    return (chain.filter { $0 != "en" } + ["en"]).filter { seen.insert($0) }
}
