import WaylandRaw

package struct PopupConfigureSequence: Equatable, Sendable {
    package let serial: UInt32
    package let placement: PopupPlacement

    package init(serial configureSerial: UInt32, placement configurePlacement: PopupPlacement) {
        serial = configureSerial
        placement = configurePlacement
    }
}

package enum PopupSurfaceConfigureResult: Equatable, Sendable {
    case waitingForPopupConfigure
    case configured(PopupConfigureSequence)
    case failed(ClientError)

    package var configure: PopupConfigureSequence? {
        guard case .configured(let configure) = self else {
            return nil
        }

        return configure
    }
}

private enum PopupConfigureRecoverablePhase {
    case waitingForPopupConfigure
    case pendingRolePayload(RawXDGPopupConfigure)
    case ready(PopupConfigureSequence)
}

private enum PopupConfigurePhase {
    case waitingForPopupConfigure
    case pendingRolePayload(RawXDGPopupConfigure)
    case ready(PopupConfigureSequence)
    case failed(ClientError, recovery: PopupConfigureRecoverablePhase)
}

package final class PopupConfigureState {
    private var phase = PopupConfigurePhase.waitingForPopupConfigure
    private var onSurfaceConfigure: (() -> Void)?

    package private(set) var hasReceivedInitialConfigure = false

    package init() {
        // Starts with no popup configure payload.
    }

    package func setSurfaceConfigureHandler(_ handler: @escaping () -> Void) {
        onSurfaceConfigure = handler
    }

    package func handlePopupConfigure(_ configure: RawXDGPopupConfigure) {
        replaceRecoverablePhase(.pendingRolePayload(configure))
    }

    package func recordError(_ error: ClientError) {
        guard case .failed = phase else {
            phase = .failed(error, recovery: recoverablePhase)
            return
        }
    }

    package func throwPendingErrorIfAny() throws {
        guard case .failed(let error, let recovery) = phase else { return }

        apply(recovery)
        throw error
    }

    @discardableResult
    package func handleSurfaceConfigure(serial: UInt32) -> PopupSurfaceConfigureResult {
        guard case .pendingRolePayload(let pendingConfigure) = recoverablePhase else {
            return .waitingForPopupConfigure
        }

        let placement: PopupPlacement
        do {
            placement = try PopupPlacement(configure: pendingConfigure)
        } catch let error as ClientError {
            recordError(error)
            return .failed(error)
        } catch {
            let clientError = ClientError.invalidWindowState(
                "unexpected popup configure error: \(error)"
            )
            recordError(clientError)
            return .failed(clientError)
        }

        let configure = PopupConfigureSequence(serial: serial, placement: placement)
        replaceRecoverablePhase(.ready(configure))
        hasReceivedInitialConfigure = true
        onSurfaceConfigure?()
        return .configured(configure)
    }

    package func consumeLatestConfigure() -> PopupConfigureSequence? {
        guard case .ready(let sequence) = recoverablePhase else {
            return nil
        }

        replaceRecoverablePhase(.waitingForPopupConfigure)
        return sequence
    }

    private var recoverablePhase: PopupConfigureRecoverablePhase {
        switch phase {
        case .waitingForPopupConfigure:
            .waitingForPopupConfigure
        case .pendingRolePayload(let configure):
            .pendingRolePayload(configure)
        case .ready(let sequence):
            .ready(sequence)
        case .failed(_, let recovery):
            recovery
        }
    }

    private func replaceRecoverablePhase(_ nextRecovery: PopupConfigureRecoverablePhase) {
        switch phase {
        case .failed(let error, _):
            phase = .failed(error, recovery: nextRecovery)
        default:
            apply(nextRecovery)
        }
    }

    private func apply(_ recovery: PopupConfigureRecoverablePhase) {
        switch recovery {
        case .waitingForPopupConfigure:
            phase = .waitingForPopupConfigure
        case .pendingRolePayload(let configure):
            phase = .pendingRolePayload(configure)
        case .ready(let sequence):
            phase = .ready(sequence)
        }
    }
}

extension PopupPlacement {
    package init(configure: RawXDGPopupConfigure) throws {
        self.init(
            origin: LogicalOffset(x: configure.x, y: configure.y),
            size: try PositiveLogicalSize(width: configure.width, height: configure.height)
        )
    }
}

extension PopupConfigureState: XDGSurfaceConfigureHandling {
    package func handleXDGSurfaceConfigure(serial: UInt32) {
        handleSurfaceConfigure(serial: serial)
    }
}
