package enum ListenerInstallState {
    case idle
    case installed

    package mutating func install(
        interface interfaceName: String,
        _ installListener: () -> Int32
    ) throws(RuntimeError) {
        guard self == .idle else {
            throw RuntimeError.listenerInstallFailed(interfaceName)
        }

        guard installListener() == 0 else {
            throw RuntimeError.listenerInstallFailed(interfaceName)
        }

        self = .installed
    }
}
