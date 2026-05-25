import WaylandRaw

package final class LiveActivationManagerBackend: ActivationManagerBackend {
    private let connection: RawDisplayConnection

    package init(connection rawConnection: RawDisplayConnection) {
        connection = rawConnection
    }

    package func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    package func requestToken(
        onDone: @escaping (RawXDGActivationTokenValue) -> Void
    ) throws -> any ActivationTokenBinding {
        try activationGlobal().requestToken(onDone: onDone)
    }

    package func activate(token: ActivationToken, surface: RawSurface) throws {
        try activationGlobal().activate(
            token: RawXDGActivationTokenValue(token.value),
            surface: surface
        )
    }

    private func activationGlobal() throws -> RawXDGActivation {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let activation) = globals.extensions.xdgActivation else {
            throw ActivationError.unavailable
        }

        return activation
    }
}
