public enum InputEventTarget: Equatable, Sendable {
    case display
    case surface(SurfaceTarget)
    case unmanagedSurface
    case focusless
}

public enum SurfaceTarget: Equatable, Sendable {
    case window(WindowID)
    case popup(PopupSurfaceIdentity, parentWindowID: WindowID)

    public var windowID: WindowID {
        switch self {
        case .window(let windowID):
            windowID
        case .popup(_, let parentWindowID):
            parentWindowID
        }
    }
}
