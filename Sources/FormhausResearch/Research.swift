import FormhausCore

public struct Research: FormResearch {
    public init() {}

    public func seed() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<2).map { _ in
            let text = String(generator.next() as UInt64, radix: 16)
            return String(repeating: "0", count: 16 - text.count) + text
        }.joined()
    }

    public func order(seed: String, key: String, options: [FieldOption]) -> [FieldOption] {
        optionOrder(seed: seed.utf16, key: key.utf16, pinned: options.map { $0.pinned || $0.exclusive }).map { options[$0] }
    }
}

func optionOrder(seed: some Sequence<UInt16>, key: some Sequence<UInt16>, pinned: [Bool]) -> [Int] {
    var state: UInt32 = 0x811C_9DC5
    let mix = { (unit: UInt16) in state = (state ^ UInt32(unit)) &* 0x0100_0193 }
    seed.forEach(mix)
    mix(0x1F)
    key.forEach(mix)
    var order = Array(pinned.indices)
    let slots = order.filter { !pinned[$0] }
    for i in stride(from: slots.count - 1, to: 0, by: -1) {
        state &+= 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (state | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        order.swapAt(slots[i], slots[Int((t ^ (t >> 14)) % UInt32(i + 1))])
    }
    return order
}
