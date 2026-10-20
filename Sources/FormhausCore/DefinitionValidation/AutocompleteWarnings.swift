private let autocompleteTypes = [
    "text", "email", "phone", "password", "textarea", "number", "date", "select", "autocomplete", "radio",
]
private let contactTypes: Set = ["home", "work", "mobile", "fax", "pager"]
private let contactNames: Set = [
    "tel", "tel-country-code", "tel-national", "tel-area-code", "tel-local", "tel-local-prefix", "tel-local-suffix", "tel-extension",
    "email", "impp",
]
private let fieldNames: Set = [
    "name", "honorific-prefix", "given-name", "additional-name", "family-name", "honorific-suffix", "nickname", "username",
    "new-password", "current-password", "one-time-code", "organization-title", "organization", "street-address", "address-line1",
    "address-line2", "address-line3", "address-level1", "address-level2", "address-level3", "address-level4", "country",
    "country-name", "postal-code", "cc-name", "cc-given-name", "cc-additional-name", "cc-family-name", "cc-number", "cc-exp",
    "cc-exp-month", "cc-exp-year", "cc-csc", "cc-type", "transaction-currency", "transaction-amount", "language", "bday",
    "bday-day", "bday-month", "bday-year", "sex", "url", "photo",
]

private func isSectionName(_ word: Substring) -> Bool {
    let name = word.utf8.dropFirst(8)
    return word.hasPrefix("section-") && !name.isEmpty
        && name.allSatisfy { (0x61...0x7A).contains($0) || (0x30...0x39).contains($0) || $0 == 0x5F || $0 == 0x2D }
}

func isAutofillToken(_ value: String) -> Bool {
    var words = value.jsTrimmed.lowercased().jsCollapsed.split(separator: " ", omittingEmptySubsequences: false)[...]
    if words.count == 1, words[words.startIndex] == "on" || words[words.startIndex] == "off" { return true }
    if let first = words.first, isSectionName(first) { words.removeFirst() }
    if let first = words.first, first == "shipping" || first == "billing" { words.removeFirst() }
    if words.count > 1, words.last == "webauthn" { words.removeLast() }
    let names = words.map(String.init)
    switch names.count {
    case 1: return fieldNames.contains(names[0]) || contactNames.contains(names[0])
    case 2: return contactTypes.contains(names[0]) && contactNames.contains(names[1])
    default: return false
    }
}

func autocompleteWarnings(_ entry: FieldEntry) -> [DefinitionIssue] {
    let field = entry.field
    guard let autocomplete = field.autocomplete else { return [] }
    let path = "\(entry.path)/autocomplete"
    if builtInTypes.contains(field.type) && !autocompleteTypes.contains(field.type) {
        return [
            warning(
                "autocomplete-not-applicable", path, "\"autocomplete\" does not apply to \(field.type) fields",
                "Use it on \(autocompleteTypes.joined(separator: ", ")) fields, or remove it")
        ]
    }
    if let token = autocomplete.stringValue, isAutofillToken(token) { return [] }
    return [
        warning(
            "unknown-autocomplete-token", path, "\(jsonStringify(autocomplete)) is not an HTML autofill token",
            "Use a token such as \"given-name\", \"email\" or \"street-address\", or \"off\"")
    ]
}
