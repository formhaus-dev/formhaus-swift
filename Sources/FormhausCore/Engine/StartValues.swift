struct StartValues {
    private var seeds = JSONObject()
    private var remembering = true
    private var memory = StringMap<JSONValue?>()

    mutating func seed(_ values: JSONObject) {
        seeds.merge(values)
    }

    mutating func resetStarts(_ values: JSONObject) {
        seeds = values
        memory = [:]
    }

    mutating func loadPayload() {
        remembering = false
        for key in seeds.keys { memory[key] = .some(nil) }
    }

    mutating func remember(_ key: String, _ value: JSONValue?) {
        guard remembering else { return }
        memory[key] = .some(value)
    }

    mutating func reseed(_ keys: [String], _ values: JSONObject) {
        for key in keys {
            memory.removeValue(forKey: key)
            seeds[key] = values[key]
        }
    }

    func startValue(_ field: FormField) -> JSONValue? {
        if field.type != "hidden", let remembered = memory[field.key] { return remembered }
        return seeds[field.key]
    }
}
