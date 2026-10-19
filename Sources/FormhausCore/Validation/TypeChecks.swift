let booleanTypes = ["checkbox", "switch"]
let builtInTypes = [
    "text", "email", "phone", "number", "password", "select", "autocomplete", "multiselect", "checkbox", "radio", "switch",
    "file", "date", "datetime", "time", "textarea", "hidden", "scale", "rating",
]
let scaleTypes = ["scale", "rating"]
let numberTypes = ["number"] + scaleTypes
let listTypes = ["multiselect"]

let maxStringLength = 10000
let maxHiddenLength = 2000
private let maxEmailLength = 254
private let maxItems = 1000
let maxGroupItems = 100

private let emailPattern = JSRegex(unchecked: "^[^\\s@]+@[^\\s@.]+(?:\\.[^\\s@.]+)+$")
private let decimal = JSRegex(unchecked: "^[+-]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][+-]?\\d+)?$")
private let datePattern = "\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])"
private let hours = "(?:[01]\\d|2[0-3]):[0-5]\\d"
private let dateOnly = JSRegex(unchecked: "^\(datePattern)$")
private let dateTime = JSRegex(unchecked: "^\(datePattern)T\(hours)(?::[0-5]\\d(?:\\.\\d{1,3})?)?(?:Z|[+-]\(hours))?$")
private let timePattern = JSRegex(unchecked: "^\(hours)(?::[0-5]\\d)?$")
private let textTypes: Set<String> = ["text", "phone", "password", "textarea", "autocomplete", "hidden"]
private let untrimmedTypes = Set(["password", "select", "radio", "file"] + numberTypes)

private enum Format {
    case email, date, datetime, time

    init?(_ type: String) {
        switch type {
        case "email": self = .email
        case "date": self = .date
        case "datetime": self = .datetime
        case "time": self = .time
        default: return nil
        }
    }

    var key: MessageKey {
        switch self {
        case .email: "email"
        case .date: "date"
        case .datetime: "datetime"
        case .time: "time"
        }
    }

    var max: Int { self == .email ? maxEmailLength : maxStringLength }

    func matches(_ value: String) -> Bool {
        switch self {
        case .email: emailPattern.test(value) == true
        case .date: dateOnly.test(value) == true && isCalendarDate(value)
        case .datetime: dateTime.test(value) == true && isCalendarDate(value)
        case .time: timePattern.test(value) == true
        }
    }
}

private func isCalendarDate(_ value: String) -> Bool {
    let parts = value.split(whereSeparator: { !($0.isASCII && $0.isNumber) }).prefix(3).compactMap { Int($0) }
    guard parts.count == 3 else { return false }
    let (year, month, day) = (parts[0], parts[1], parts[2])
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return day <= days[month - 1]
}

func trimValue(_ field: FormField, _ value: JSONValue?) -> JSONValue? {
    guard case .string(let text)? = value, !untrimmedTypes.contains(field.type) else { return value }
    return .string(text.jsTrimmed)
}

func normalizeValue(_ field: FormField, _ input: JSONValue?) -> JSONValue? {
    if let items = input?.arrayValue, items.isEmpty, !listTypes.contains(field.type), builtInTypes.contains(field.type) { return nil }
    if field.isGroup { return normalizeItems(field, input) }
    let value = trimValue(field, input)
    guard numberTypes.contains(field.type), case .string(let text)? = value, decimal.test(text) == true else { return value }
    let parsed = jsNumber(fromString: text)
    return parsed.isFinite ? .number(parsed) : value
}

private func normalizeItems(_ group: FormField, _ input: JSONValue?) -> JSONValue? {
    guard let items = input?.arrayValue, Double(items.count) <= group.validation?.maxLength ?? Double(maxGroupItems) else { return input }
    return .array(
        items.map { item in
            guard let entry = item.objectValue else { return item }
            var result = JSONObject()
            for field in group.items where entry.has(field.key) {
                if let value = normalizeValue(field, entry[field.key]) { result[field.key] = value }
            }
            return .object(result)
        }
    )
}

private func staticOptions(_ field: FormField) -> [FieldOption]? {
    field.hasOptionsFrom ? nil : field.options
}

private func isOption(_ field: FormField, _ value: JSONValue) -> Bool {
    guard let options = staticOptions(field) else { return true }
    return options.contains { strictEquals($0.json["value"], value) }
}

private typealias Fail = (MessageKey, JSONObject) -> String

private func lengthError(_ field: FormField, _ value: String, _ fail: Fail) -> String? {
    let fallback = Double(field.type == "hidden" ? maxHiddenLength : maxStringLength)
    let max = Swift.min(Double(maxStringLength), field.validation?.maxLength ?? fallback)
    guard Double(value.jsLength) > max else { return nil }
    return field.validation?.message("maxLengthMessage") ?? fail("maxLength", ["max": .number(max)])
}

private func multiselectError(_ field: FormField, _ value: JSONValue, _ fail: Fail) -> String? {
    guard let items = value.arrayValue else { return fail("options", [:]) }
    if items.count > staticOptions(field)?.count ?? maxItems { return fail("option", [:]) }
    let valid = items.allSatisfy { item in
        guard let text = item.stringValue else { return false }
        return text.jsLength <= maxStringLength && isOption(field, item)
    }
    return valid ? nil : fail("option", [:])
}

private func stringError(_ field: FormField, _ value: JSONValue, _ key: MessageKey, _ fail: Fail) -> String? {
    guard let text = value.stringValue else { return fail(key, [:]) }
    return lengthError(field, text, fail)
}

private func formatError(_ field: FormField, _ value: JSONValue, _ format: Format, _ fail: Fail) -> String? {
    guard let text = value.stringValue else { return fail(format.key, [:]) }
    if let error = lengthError(field, text, fail) { return error }
    return text.jsLength <= format.max && format.matches(text) ? nil : fail(format.key, [:])
}

private func primitiveError(_ field: FormField, _ value: JSONValue, _ fail: Fail) -> String? {
    if value.boolValue != nil || value.isFiniteNumber { return nil }
    return stringError(field, value, "value", fail)
}

private func isEmpty(_ field: FormField, _ value: JSONValue?) -> Bool {
    isBlank(value) && (listTypes.contains(field.type) || value?.arrayValue == nil)
}

private func groupError(_ field: FormField, _ value: JSONValue, _ fail: Fail) -> String? {
    let max = field.validation?.maxLength
    guard let items = value.arrayValue else { return fail("value", [:]) }
    if let max, Double(items.count) > max {
        return field.validation?.message("maxLengthMessage") ?? fail("maxItems", ["max": .number(max)])
    }
    return Double(items.count) > max ?? Double(maxGroupItems) || !items.allSatisfy({ $0.objectValue != nil }) ? fail("value", [:]) : nil
}

func typeError(_ field: FormField, _ input: JSONValue?, _ resolve: @escaping ResolveMessage = messageResolver()) -> String? {
    guard let value = input, !isEmpty(field, input) else { return nil }
    let fail: Fail = { key, params in resolve(key, params, field) }
    if field.isGroup { return groupError(field, value, fail) }
    if booleanTypes.contains(field.type) { return value.boolValue != nil ? nil : fail("boolean", [:]) }
    if field.type == "number" { return value.isFiniteNumber ? nil : fail("number", [:]) }
    if let range = field.scaleRange {
        let point = value.numberValue.map { $0.isInteger && range.min <= $0 && $0 <= range.max }
        return point == true ? nil : fail("option", [:])
    }
    if listTypes.contains(field.type) { return multiselectError(field, value, fail) }
    if field.type == "file" { return stringError(field, value, "file", fail) }
    if let format = Format(field.type) { return formatError(field, value, format, fail) }
    if field.type == "select" || field.type == "radio" {
        return stringError(field, value, "option", fail) ?? (isOption(field, value) ? nil : fail("option", [:]))
    }
    return textTypes.contains(field.type) ? stringError(field, value, "string", fail) : primitiveError(field, value, fail)
}

func typeMessageKeys(_ field: FormField) -> [MessageKey] {
    if field.isGroup { return ["value"] }
    if booleanTypes.contains(field.type) { return ["boolean"] }
    if field.type == "number" { return ["number"] }
    if field.isScale { return ["option"] }
    if listTypes.contains(field.type) { return ["options", "option"] }
    if let format = Format(field.type) { return [format.key, "maxLength"] }
    if field.type == "file" { return ["file", "maxLength"] }
    if field.type == "select" || field.type == "radio" { return ["option", "maxLength"] }
    return [textTypes.contains(field.type) ? "string" : "value", "maxLength"] + (field.type == "hidden" ? ["hidden"] : [])
}

func clientTypeError(_ field: FormField, _ value: JSONValue?, _ resolve: @escaping ResolveMessage) -> String? {
    if field.type == "file" || (!builtInTypes.contains(field.type) && !field.isGroup) { return nil }
    return typeError(field, value, resolve)
}
