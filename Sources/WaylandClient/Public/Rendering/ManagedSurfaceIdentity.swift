/// Identifies a managed software surface independently of a presentation request.
public enum ManagedSurfaceIdentity: Hashable, Sendable {
    case window(WindowID)
    case popup(PopupSurfaceIdentity)
    case subsurface(SubsurfaceIdentity)
}
