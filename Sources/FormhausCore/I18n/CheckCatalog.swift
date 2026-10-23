public struct CatalogIssues: Sendable, Hashable {
    public let missing: [String]
    public let unknown: [String]
}

private let pluralNames = ["zero", "one", "two", "few", "many", "other"]

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
