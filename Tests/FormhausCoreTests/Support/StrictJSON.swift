import FormhausCore

func sameUnits(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf16.elementsEqual(rhs.utf16)
}

func strictlyEqual(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil), (.null?, .null?): return true
    case (.bool(let a)?, .bool(let b)?): return a == b
    case (.number(let a)?, .number(let b)?): return a.bitPattern == b.bitPattern || (a.isNaN && b.isNaN)
    case (.string(let a)?, .string(let b)?): return sameUnits(a, b)
    case (.array(let a)?, .array(let b)?): return a.count == b.count && zip(a, b).allSatisfy { strictlyEqual($0, $1) }
    case (.object(let a)?, .object(let b)?):
        guard a.count == b.count else { return false }
        return a.allSatisfy { entry in
            let matches = b.filter { sameUnits($0.key, entry.key) }
            return matches.count == 1 && strictlyEqual(entry.value, matches[0].value)
        }
    default: return false
    }
}

func json(_ errors: FieldErrors) -> JSONValue {
    var object = JSONObject()
    for (key, message) in errors { object[key] = .string(message) }
    return .object(object)
}

func duplicates(_ names: [String]) -> [String] {
    var seen: [String] = []
    var repeated: [String] = []
    for name in names {
        if seen.contains(where: { sameUnits($0, name) }) {
            if !repeated.contains(where: { sameUnits($0, name) }) { repeated.append(name) }
        } else {
            seen.append(name)
        }
    }
    return repeated
}
