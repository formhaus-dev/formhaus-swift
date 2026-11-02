struct StartValues {
    private var seeds = Values()
    private var stored: JSONObject?
    private var remembering = true
    private var writeWatch: (id: Int, keys: KeySet)?
    private var memory = StringMap<ValueSlot>(insertionOrder: true)
    private var itemSeeds: [Int: JSONObject] = [:]
    private var itemMemory: [Int: JSONObject] = [:]
    private var itemHidden: [Int: KeySet] = [:]
    private(set) var itemEpoch = 0

    private mutating func forgetItems() {
        itemSeeds = [:]
        itemMemory = [:]
        itemHidden = [:]
        itemEpoch += 1
    }

    mutating func seedItems(_ slot: ValueSlot) {
        itemEpoch += 1
        let ids = slot.ref?.items ?? []
        for (index, item) in itemsOf(slot.value).enumerated() {
            if let entry = item.objectValue, ids.indices.contains(index), itemSeeds[ids[index]] == nil { itemSeeds[ids[index]] = entry }
        }
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

    mutating func seedWritten(_ group: FormField, _ slot: ValueSlot) {
        guard remembering, let ids = slot.ref?.items else { return }
        var seeded = false
        for (index, item) in itemsOf(slot.value).enumerated() where ids.indices.contains(index) && itemSeeds[ids[index]] == nil {
            guard let entry = item.objectValue else { continue }
            var seed = createItem(group.items)
            seed.merge(entry)
            itemSeeds[ids[index]] = seed
            seeded = true
        }
        if seeded { itemEpoch += 1 }
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
        itemHidden.removeValue(forKey: id)
    }

    mutating func hideItem(_ id: Int?, _ key: String) {
        guard let id else { return }
        itemHidden[id, default: KeySet()].insert(key)
    }

    mutating func revealItem(_ id: Int?, _ key: String) -> Bool {
        guard let id else { return false }
        return itemHidden[id]?.remove(key) ?? false
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

    mutating func storeValues(_ values: JSONObject) {
        stored = values
    }

    var previousValues: JSONObject { stored ?? seeds.json }

    func startValue(_ field: FormField) -> ValueSlot {
        if field.type != "hidden", let remembered = memory[field.key] { return remembered }
        return seeds.slot(field.key)
    }

    func itemStartValue(_ id: Int?, _ field: FormField) -> JSONValue? {
        guard let id else { return nil }
        if field.type != "hidden", let remembered = itemMemory[id], remembered.has(field.key) { return remembered[field.key] }
        return itemSeeds[id]?[field.key]
    }
}
