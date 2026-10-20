func exclusiveWrite(_ field: FormField?, _ previous: JSONValue?, _ next: JSONValue?) -> JSONValue? {
    guard let field, let items = next?.arrayValue else { return next }
    let exclusive = exclusiveValues(field)
    guard !exclusive.isEmpty else { return next }
    let isExclusive = { (value: JSONValue) in exclusive.contains { sameValueZero($0, value) } }
    let before = previous?.arrayValue ?? []
    let added = items.filter { item in !before.contains { sameValueZero($0, item) } }
    if let picked = added.last(where: isExclusive) { return .array([picked]) }
    let rest = items.filter { !isExclusive($0) }
    return !added.isEmpty && rest.count < items.count ? .array(rest) : next
}
