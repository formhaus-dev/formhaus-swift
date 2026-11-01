@_spi(Renderer) import FormhausCore

extension FormModel {
    public var dirtyKeys: [String] {
        dirtyTracker.follow()
        _ = trackedDirtyKeys
        return dirtyTracker.dirtyKeys
    }

    public var isDirty: Bool { !dirtyKeys.isEmpty }

    public func markClean() {
        dirtyTracker.follow()
        dirtyTracker.markClean()
        if trackedDirtyKeys != dirtyTracker.dirtyKeys { trackedDirtyKeys = dirtyTracker.dirtyKeys }
    }
}
