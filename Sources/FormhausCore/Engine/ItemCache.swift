struct ItemContext: Equatable {
    var values: [JSONValue?]
    var lengths: [Int?]
    var epoch: Int
}

final class ItemCache<Output> {
    private struct Sources {
        let outer: [String]
        let all: [String]
    }

    private struct Entry {
        let context: ItemContext
        let ids: [Int]
        let inputs: [JSONValue]
        let outputs: [Output?]
        let whole: [Output]?

        func output(_ position: Int, _ item: JSONValue, _ ids: [Int]) -> Output? {
            guard inputs.indices.contains(position), let output = outputs[position] else { return nil }
            let id = ids.indices.contains(position) ? ids[position] : nil
            let known = self.ids.indices.contains(position) ? self.ids[position] : nil
            guard id == known, inputs[position] == item else { return nil }
            return output
        }
    }

    private var sources: [Int: Sources] = [:]
    private var entries: [Int: Entry] = [:]

    private func sources(_ group: FormField) -> Sources {
        if let known = sources[group.ordinal] { return known }
        let items = group.items
        let inner = KeySet(items.map(\.key))
        let all = OrderedKeys(items.flatMap(\.conditionFields)).keys
        let found = Sources(outer: all.filter { !inner.contains($0) }, all: all)
        sources[group.ordinal] = found
        return found
    }

    func context(_ group: FormField, _ scope: JSONObject, _ limits: ListLimits, epoch: Int = 0) -> ItemContext {
        let keys = sources(group)
        return ItemContext(values: keys.outer.map { scope[$0] }, lengths: keys.all.map(limits.length), epoch: epoch)
    }

    func map(
        _ group: FormField, _ items: [JSONValue], ids: [Int] = [], context: ItemContext,
        _ transform: (Int, JSONValue) -> (value: Output, keep: Bool)
    ) -> (items: [Output], reused: Bool) {
        let previous = entries[group.ordinal].flatMap { $0.context == context ? $0 : nil }
        if let previous, let whole = previous.whole, previous.inputs == items, previous.ids == ids { return (whole, true) }
        var outputs: [Output?] = []
        var result: [Output] = []
        outputs.reserveCapacity(items.count)
        result.reserveCapacity(items.count)
        for (position, item) in items.enumerated() {
            if let previous, let output = previous.output(position, item, ids) {
                outputs.append(output)
                result.append(output)
                continue
            }
            let mapped = transform(position, item)
            outputs.append(mapped.keep ? mapped.value : nil)
            result.append(mapped.value)
        }
        let complete = outputs.allSatisfy { $0 != nil }
        entries[group.ordinal] = Entry(context: context, ids: ids, inputs: items, outputs: outputs, whole: complete ? result : nil)
        return (result, false)
    }
}
