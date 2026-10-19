struct StartValues {
    private var seeds = Values()
    private var remembering = true
    private var writeWatch: (id: Int, keys: KeySet)?
    private var memory = StringMap<ValueSlot>()
    private var itemSeeds: [Int: JSONObject] = [:]
    private var itemMemory: [Int: JSONObject] = [:]

    private mutating func forgetItems() {
        itemSeeds = [:]
        itemMemory = [:]
    }

    mutating func seedItems(_ slot: ValueSlot) {
        let ids = slot.ref?.items ?? []
        for (index, item) in itemsOf(slot.value).enumerated() {
            if let entry = item.objectValue, ids.indices.contains(index) { itemSeeds[ids[index]] = entry }
        }
    }

    mutating func seed(_ values: Values) {
        seeds.merge(values)
    }

    mutating func resetStarts(_ values: Values, groups: [FormField]) {
        seeds = values
        memory = [:]
        forgetItems()
        for group in groups { seedItems(values.slot(group.key)) }
    }

    mutating func loadPayload() {
        remembering = false
        forgetItems()
        for key in seeds.keys { memory[key] = ValueSlot(nil, ref: nil) }
    }

    mutating func remember(_ key: String, _ slot: ValueSlot, written: Bool = false) {
        guard remembering else { return }
        memory[key] = slot
        if written { writeWatch?.keys.insert(key) }
    }

    mutating func watchWrites() -> Int {
        let id = freshToken()
        writeWatch = (id, KeySet())
        return id
    }

    mutating func endWatch(_ id: Int) -> KeySet {
        guard let watch = writeWatch, watch.id == id else { return KeySet() }
        writeWatch = nil
        return watch.keys
    }

    mutating func rememberItem(_ id: Int?, _ key: String, _ value: JSONValue) {
        guard remembering, let id else { return }
        itemMemory[id, default: JSONObject()][key] = value
    }

    mutating func dropItem(_ id: Int?) {
        guard let id else { return }
        itemSeeds.removeValue(forKey: id)
        itemMemory.removeValue(forKey: id)
    }

    typealias Restore = (keys: [String], seeds: [ValueSlot], memory: [ValueSlot?])

    mutating func reseed(_ keys: [String], _ values: Values) -> Restore {
        let previous: Restore = (keys, keys.map { seeds.slot($0) }, keys.map { memory[$0] })
        for key in keys {
            memory.removeValue(forKey: key)
            seeds.set(key, values.slot(key))
            seedItems(values.slot(key))
        }
        return previous
    }

    mutating func restore(_ previous: Restore, kept: KeySet) {
        for (index, key) in previous.keys.enumerated() {
            seeds.set(key, previous.seeds[index])
            if kept.contains(key) { continue }
            if let remembered = previous.memory[index] {
                memory[key] = remembered
            } else {
                memory.removeValue(forKey: key)
            }
        }
    }

    func startValue(_ field: FormField) -> ValueSlot {
        if field.type != "hidden", let remembered = memory[field.key] { return remembered }
        return seeds.slot(field.key)
    }

    func itemStartValue(_ id: Int?, _ key: String) -> JSONValue? {
        guard let id else { return nil }
        if let remembered = itemMemory[id], remembered.has(key) { return remembered[key] }
        return itemSeeds[id]?[key]
    }
}
