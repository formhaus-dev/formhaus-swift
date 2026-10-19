@_spi(Renderer) import FormhausCore
import SwiftUI

extension FormModel {
    public func itemTitle(_ index: Int, inGroup key: String) -> String {
        guard let group = groupField(key) else { return "" }
        return engine.itemTitle(group, index, options.labels)
    }

    @discardableResult
    public func addItem(toGroup key: String) -> Bool {
        let count = group(key).items.count
        guard changeItems(ofGroup: key, using: { engine.addItem(key) }) else { return false }
        if let first = group(key).items.last?.fields.first(where: { $0.type != "hidden" }) {
            requestFocus("\(key).\(count).\(first.key)")
        }
        announce(text(forLabel: "itemAdded", ["item": .string(itemTitle(count, inGroup: key))]))
        return true
    }

    @discardableResult
    public func removeItem(_ index: Int, fromGroup key: String) -> Bool {
        let name = itemTitle(index, inGroup: key)
        guard changeItems(ofGroup: key, using: { engine.removeItem(key, index) }) else { return false }
        requestFocus(key)
        announce(text(forLabel: "itemRemoved", ["item": .string(name)]))
        return true
    }

    func groupField(_ key: String) -> FormField? {
        structure.visibleFields.first { $0.key == key && $0.isGroup }
    }
}
