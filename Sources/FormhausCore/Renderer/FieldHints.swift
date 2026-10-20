private func sectionName(_ key: String) -> String {
    var name = ""
    for unit in key.utf16 {
        if (0x61...0x7A).contains(unit) || (0x30...0x39).contains(unit) {
            name.unicodeScalars.append(Unicode.Scalar(UInt8(unit)))
        } else {
            name += "_\(String(unit, radix: 16))_"
        }
    }
    return name
}

@_spi(Renderer)
public func dividerBefore(_ field: FormField, _ options: [FieldOption], _ index: Int) -> Bool {
    !field.hasOptionsFrom && options.indices.contains(index) && options[index].exclusive && index > 0 && !options[index - 1].exclusive
}

extension FormEngine {
    @_spi(Renderer)
    public func autocomplete(_ field: FormField, at path: String? = nil) -> String? {
        guard let written = field.autocomplete?.stringValue else { return nil }
        let token = written.jsTrimmed
        let lower = token.lowercased()
        guard let path, !token.isEmpty, lower != "on", lower != "off", let parts = core.visibility.parse(path) else { return written }
        let section = "section-\(sectionName(parts.group))-\(parts.index)"
        guard lower.hasPrefix("section-") else { return "\(section) \(token)" }
        return "\(section)-\(token.dropFirst(8))"
    }
}
