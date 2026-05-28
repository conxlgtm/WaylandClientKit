extension WaylandDisplay {
    package func setWindowInputRegion(
        _ windowID: WindowID,
        _ region: SurfaceRegion?
    ) throws {
        try requireCore().setWindowInputRegion(windowID, region)
    }

    package func setWindowOpaqueRegion(
        _ windowID: WindowID,
        _ region: SurfaceRegion?
    ) throws {
        try requireCore().setWindowOpaqueRegion(windowID, region)
    }

    package func setPopupInputRegion(
        _ popupID: PopupID,
        _ region: SurfaceRegion?
    ) throws {
        try requireCore().setPopupInputRegion(popupID, region)
    }

    package func setPopupOpaqueRegion(
        _ popupID: PopupID,
        _ region: SurfaceRegion?
    ) throws {
        try requireCore().setPopupOpaqueRegion(popupID, region)
    }
}
