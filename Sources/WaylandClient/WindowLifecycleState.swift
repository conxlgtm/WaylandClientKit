import WaylandRaw

enum WindowLifecycleState: Equatable, CustomStringConvertible {
    case created
    case roleAssigned
    case waitingForInitialConfigure
    case configured(SurfaceConfigure)
    case mapped
    case closeRequested
    case destroyed

    var description: String {
        switch self {
        case .created:
            "created"
        case .roleAssigned:
            "roleAssigned"
        case .waitingForInitialConfigure:
            "waitingForInitialConfigure"
        case .configured(let configure):
            "configured(serial: \(configure.serial), "
                + "\(configure.size.width)x\(configure.size.height))"
        case .mapped:
            "mapped"
        case .closeRequested:
            "closeRequested"
        case .destroyed:
            "destroyed"
        }
    }
}
