public let defaultMessageKeys = [
    "required", "minLength", "maxLength", "minItems", "maxItems", "min", "max", "pattern", "matchField", "email",
    "number", "date", "datetime", "time", "option", "options", "boolean", "string", "file", "value", "hidden",
]

public let defaultMessages: [String: String] = [
    "required": "This field is required",
    "minLength": "Must be at least {min} characters",
    "maxLength": "Must be at most {max} characters",
    "minItems": "Must be at least {min} items",
    "maxItems": "Must be at most {max} items",
    "min": "Must be at least {min}",
    "max": "Must be at most {max}",
    "pattern": "Invalid format",
    "matchField": "Fields must match",
    "email": "Enter a valid email",
    "number": "Enter a number",
    "date": "Enter a valid date",
    "datetime": "Enter a valid date and time",
    "time": "Enter a valid time",
    "option": "Select one of the available options",
    "options": "Must be a list of available options",
    "boolean": "Must be true or false",
    "string": "Must be text",
    "file": "Must be a file reference",
    "value": "Invalid value",
    "hidden": "{label}: {message}",
]

public typealias MessageParams = JSONObject
public typealias MessageFn = (String, MessageParams, FormField) -> String?
public typealias ResolveMessage = (String, MessageParams, FormField) -> String

public enum MessageSource {
    case catalog(JSONValue)
    case function(MessageFn)
}

private func isWordUnit(_ unit: UInt16) -> Bool {
    (0x30...0x39).contains(unit) || (0x41...0x5A).contains(unit) || (0x61...0x7A).contains(unit) || unit == 0x5F
}

func replacePlaceholders(_ template: String, _ replacement: (String) -> String?) -> String {
    let units = Array(template.utf16)
    var output: [UInt16] = []
    var index = 0
    while index < units.count {
        if units[index] == 0x7B {
            var end = index + 1
            while end < units.count, isWordUnit(units[end]) { end += 1 }
            if end > index + 1, end < units.count, units[end] == 0x7D {
                let name = String(decoding: units[(index + 1)..<end], as: UTF16.self)
                output += replacement(name).map { Array($0.utf16) } ?? Array(units[index...end])
                index = end + 1
                continue
            }
        }
        output.append(units[index])
        index += 1
    }
    return String(decoding: output, as: UTF16.self)
}

func formatText(_ template: String, _ params: JSONObject) -> String {
    replacePlaceholders(template) { params[$0].map { jsString($0) } }
}

func resolveText(
    _ defaults: [String: String], _ key: String, _ params: JSONObject, _ sources: [MessageSource?], _ field: FormField?
) -> String {
    for source in sources {
        switch source {
        case .function(let resolve)?:
            if let field, let text = resolve(key, params, field), !text.isEmpty { return text }
        case .catalog(let catalog)?:
            if let text = catalog[key]?.stringValue, !text.isEmpty { return formatText(text, params) }
        case nil:
            continue
        }
    }
    return formatText(defaults[key] ?? "", params)
}

func messageResolver(_ sources: MessageSource?...) -> ResolveMessage {
    { key, params, field in resolveText(defaultMessages, key, params, sources, field) }
}

func namedResolver(_ resolve: @escaping ResolveMessage) -> ResolveMessage {
    { key, params, field in
        let message = resolve(key, params, field)
        guard field.type == "hidden" else { return message }
        let label = field.label.flatMap { $0.isEmpty ? nil : $0 } ?? field.key
        return resolve("hidden", ["label": .string(label), "message": .string(message)], field)
    }
}

public func getDefaultMessage(_ rule: String, _ params: JSONObject = JSONObject()) -> String {
    let template = defaultMessages[rule] ?? defaultMessages["value"]!
    let custom = params.has("unit") && (rule == "minLength" || rule == "maxLength")
    return formatText(custom ? template.replacingOccurrences(of: "characters", with: "{unit}") : template, params)
}
