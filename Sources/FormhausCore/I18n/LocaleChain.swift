import Foundation

public struct CatalogIssues: Sendable, Hashable {
    public let missing: [String]
    public let unknown: [String]
}

private let pluralNames = ["zero", "one", "two", "few", "many", "other"]

private func isLetter(_ scalar: Unicode.Scalar) -> Bool {
    ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
}

private func isDigit(_ scalar: Unicode.Scalar) -> Bool {
    ("0"..."9").contains(scalar)
}

private func only(_ text: Substring, _ allowed: (Unicode.Scalar) -> Bool) -> Bool {
    text.unicodeScalars.allSatisfy(allowed)
}

private func isVariant(_ text: Substring) -> Bool {
    guard only(text, { isLetter($0) || isDigit($0) }) else { return false }
    return (5...8).contains(text.count) || (text.count == 4 && text.unicodeScalars.first.map(isDigit) == true)
}

private func canonicalTag(_ tag: String) -> [String]? {
    let subtags = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-", omittingEmptySubsequences: false)
    let cut = subtags.indices.dropFirst().first { subtags[$0].count == 1 } ?? subtags.count
    guard let language = subtags.first, [2, 3, 5, 6, 7, 8].contains(language.count), only(language, isLetter) else {
        return nil
    }
    var rest = subtags[1..<cut]
    var parts = [language.lowercased()]
    if let script = rest.first, script.count == 4, only(script, isLetter) {
        parts.append(script.prefix(1).uppercased() + script.dropFirst().lowercased())
        rest = rest.dropFirst()
    }
    if let region = rest.first, region.count == 2 ? only(region, isLetter) : region.count == 3 && only(region, isDigit) {
        parts.append(region.uppercased())
        rest = rest.dropFirst()
    }
    let variants = rest.map { $0.lowercased() }
    guard rest.allSatisfy(isVariant), Set(variants).count == variants.count else { return nil }
    return parts + variants.sorted()
}

public func localeChain(_ tag: String) -> [String] {
    var chain: [String] = []
    if let parts = canonicalTag(tag) {
        chain = parts.indices.reversed().map { parts[...$0].joined(separator: "-") }
        let likely = Locale.Language(identifier: Locale.Language(identifier: chain[0]).maximalIdentifier)
        if let language = likely.languageCode?.identifier, let region = likely.region?.identifier {
            chain.insert("\(language)-\(region)", at: max(chain.count - 1, 1))
        }
    }
    var seen = KeySet()
    return (chain.filter { $0 != "en" } + ["en"]).filter { seen.insert($0) }
}

public func checkCatalog(_ catalog: JSONValue?) -> CatalogIssues {
    let root = catalog?.objectValue ?? JSONObject()
    var missing: [String] = root["locale"]?.stringValue.map(\.isBlankText) == false ? [] : ["locale"]
    var unknown = root.keys.filter { !["locale", "messages", "labels"].containsText($0) }
    for (part, known) in [("messages", defaultMessageKeys.map(\.rawValue)), ("labels", defaultLabelKeys)] {
        let block = root[part]?.objectValue ?? JSONObject()
        for key in known {
            if let forms = block[key]?.objectValue {
                if forms["other"]?.stringValue.map(\.isBlankText) != false { missing.append("\(part).\(key).other") }
                unknown += forms.compactMap { form, text in
                    pluralNames.contains(form) && text.stringValue != nil ? nil : "\(part).\(key).\(form)"
                }
            } else if block[key]?.stringValue.map(\.isBlankText) != false {
                missing.append("\(part).\(key)")
            }
        }
        unknown += block.keys.filter { !known.containsText($0) }.map { "\(part).\($0)" }
    }
    return CatalogIssues(missing: missing, unknown: unknown)
}
