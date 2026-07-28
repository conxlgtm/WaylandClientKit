/// Identifies a managed software surface independently of a presentation request.
public enum ManagedSurfaceIdentity: Hashable, Sendable {
    /// A top-level managed window.
    case window(WindowID)
    /// An xdg-shell popup.
    case popup(PopupSurfaceIdentity)
    /// A managed subsurface child.
    case subsurface(SubsurfaceIdentity)
}
