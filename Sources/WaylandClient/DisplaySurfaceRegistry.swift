struct DisplaySurfaceIndex: Equatable, Sendable {
    private(set) var windowSurfaceIDs: [WindowID: SurfaceID] = [:]
    private(set) var popupSurfaceIDs: [PopupID: SurfaceID] = [:]
    private(set) var popupParentWindowIDs: [PopupID: WindowID] = [:]
    private(set) var closedPopupIDs: Set<PopupID> = []
    private(set) var pendingPopupRegistryRemovalIDs: Set<PopupID> = []

    init() {
        // Starts with no registered role surfaces.
    }

    var windowIDs: Set<WindowID> {
        Set(windowSurfaceIDs.keys)
    }

    var popupIDs: Set<PopupID> {
        Set(popupSurfaceIDs.keys)
    }

    mutating func insertWindow(windowID: WindowID, surfaceID: SurfaceID) {
        windowSurfaceIDs[windowID] = surfaceID
    }

    @discardableResult
    mutating func removeWindow(_ windowID: WindowID) -> SurfaceID? {
        windowSurfaceIDs.removeValue(forKey: windowID)
    }

    mutating func insertPopup(
        popupID: PopupID,
        surfaceID: SurfaceID,
        parentWindowID: WindowID
    ) {
        popupSurfaceIDs[popupID] = surfaceID
        popupParentWindowIDs[popupID] = parentWindowID
        closedPopupIDs.remove(popupID)
    }

    @discardableResult
    mutating func removePopup(_ popupID: PopupID) -> SurfaceID? {
        popupParentWindowIDs.removeValue(forKey: popupID)
        return popupSurfaceIDs.removeValue(forKey: popupID)
    }

    @discardableResult
    mutating func markPopupClosed(_ popupID: PopupID) -> WindowID? {
        let parentWindowID = popupParentWindowIDs[popupID]
        closedPopupIDs.insert(popupID)
        removePopup(popupID)
        return parentWindowID
    }

    mutating func removeAll() {
        windowSurfaceIDs.removeAll(keepingCapacity: false)
        popupSurfaceIDs.removeAll(keepingCapacity: false)
        popupParentWindowIDs.removeAll(keepingCapacity: false)
        closedPopupIDs.removeAll(keepingCapacity: false)
        pendingPopupRegistryRemovalIDs.removeAll(keepingCapacity: false)
    }

    mutating func beginPopupRegistryRemoval(for popupIDs: [PopupID]) {
        pendingPopupRegistryRemovalIDs.formUnion(popupIDs)
    }

    mutating func finishPopupRegistryRemoval(for popupID: PopupID) {
        pendingPopupRegistryRemovalIDs.remove(popupID)
    }
}

struct DisplayWindowRecord {
    let window: TopLevelWindow
    let surfaceID: SurfaceID
}

struct DisplayPopupRecord {
    let popup: PopupRoleSurface
    let surfaceID: SurfaceID
    let parentWindowID: WindowID
}

struct DisplaySurfaceRegistry {
    private var windowRecords: [WindowID: DisplayWindowRecord] = [:]
    private var popupRecords: [PopupID: DisplayPopupRecord] = [:]
    private var closedPopupIDsStorage: Set<PopupID> = []
    private var pendingPopupRegistryRemovalIDsStorage: Set<PopupID> = []

    var windowIDs: Set<WindowID> {
        Set(windowRecords.keys)
    }

    var popupIDs: Set<PopupID> {
        Set(popupRecords.keys)
    }

    var allWindowIDs: [WindowID] {
        Array(windowRecords.keys)
    }

    var windowSurfaceIDs: [WindowID: SurfaceID] {
        windowRecords.mapValues { record in record.surfaceID }
    }

    var popupSurfaceIDs: [PopupID: SurfaceID] {
        popupRecords.mapValues { record in record.surfaceID }
    }

    var closedPopupIDs: Set<PopupID> {
        closedPopupIDsStorage
    }

    var pendingPopupRegistryRemovalIDs: Set<PopupID> {
        pendingPopupRegistryRemovalIDsStorage
    }

    var surfaceIndex: DisplaySurfaceIndex {
        var snapshot = DisplaySurfaceIndex()
        for (windowID, record) in windowRecords {
            snapshot.insertWindow(windowID: windowID, surfaceID: record.surfaceID)
        }
        for (popupID, record) in popupRecords {
            snapshot.insertPopup(
                popupID: popupID,
                surfaceID: record.surfaceID,
                parentWindowID: record.parentWindowID
            )
        }
        for closedPopupID in closedPopupIDsStorage {
            snapshot.markPopupClosed(closedPopupID)
        }
        snapshot.beginPopupRegistryRemoval(
            for: Array(pendingPopupRegistryRemovalIDsStorage)
        )
        return snapshot
    }

    func window(_ windowID: WindowID) -> TopLevelWindow? {
        windowRecords[windowID]?.window
    }

    func popup(_ popupID: PopupID) -> PopupRoleSurface? {
        popupRecords[popupID]?.popup
    }

    func windowSurfaceID(_ windowID: WindowID) -> SurfaceID? {
        windowRecords[windowID]?.surfaceID
    }

    func popupSurfaceID(_ popupID: PopupID) -> SurfaceID? {
        popupRecords[popupID]?.surfaceID
    }

    func popupParentWindowID(_ popupID: PopupID) -> WindowID? {
        popupRecords[popupID]?.parentWindowID
    }

    mutating func insertWindow(_ window: TopLevelWindow, surfaceID: SurfaceID) {
        windowRecords[window.id] = DisplayWindowRecord(
            window: window,
            surfaceID: surfaceID
        )
    }

    @discardableResult
    mutating func removeWindow(_ windowID: WindowID) -> DisplayWindowRecord? {
        windowRecords.removeValue(forKey: windowID)
    }

    mutating func insertPopup(
        _ popup: PopupRoleSurface,
        surfaceID: SurfaceID,
        parentWindowID: WindowID
    ) {
        popupRecords[popup.id] = DisplayPopupRecord(
            popup: popup,
            surfaceID: surfaceID,
            parentWindowID: parentWindowID
        )
        closedPopupIDsStorage.remove(popup.id)
    }

    @discardableResult
    mutating func removePopup(_ popupID: PopupID) -> DisplayPopupRecord? {
        popupRecords.removeValue(forKey: popupID)
    }

    @discardableResult
    mutating func markPopupClosed(_ popupID: PopupID) -> WindowID? {
        let parentWindowID = popupRecords[popupID]?.parentWindowID
        closedPopupIDsStorage.insert(popupID)
        popupRecords.removeValue(forKey: popupID)
        return parentWindowID
    }

    mutating func removeAll() {
        windowRecords.removeAll(keepingCapacity: false)
        popupRecords.removeAll(keepingCapacity: false)
        closedPopupIDsStorage.removeAll(keepingCapacity: false)
        pendingPopupRegistryRemovalIDsStorage.removeAll(keepingCapacity: false)
    }

    mutating func beginPopupRegistryRemoval(for popupIDs: [PopupID]) {
        pendingPopupRegistryRemovalIDsStorage.formUnion(popupIDs)
    }

    mutating func finishPopupRegistryRemoval(for popupID: PopupID) {
        pendingPopupRegistryRemovalIDsStorage.remove(popupID)
    }
}
