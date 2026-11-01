@_spi(Renderer) import FormhausCore

extension FormModel {
    public var dirtyKeys: [String] {
        followDirty()
        return trackedDirtyKeys
    }

    public var isDirty: Bool { !dirtyKeys.isEmpty }

    public func markClean() {
        dirtyTracker.follow()
        dirtyTracker.markClean()
        syncDirtyKeys()
    }

    private func followDirty() {
        guard !dirtyTracker.following else { return }
        dirtyTracker.follow()
        syncDirtyKeys()
    }

    private func syncDirtyKeys() {
        if trackedDirtyKeys != dirtyTracker.dirtyKeys { trackedDirtyKeys = dirtyTracker.dirtyKeys }
    }
}
