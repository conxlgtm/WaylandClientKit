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
    case waitingForInitialPopupConfigure
    case pendingInitialRolePayload(RawXDGPopupConfigure)
    case waitingForPopupConfigure
    case pendingRolePayload(RawXDGPopupConfigure)
    case ready(PopupConfigureSequence)

    var hasReceivedInitialConfigure: Bool {
        switch self {
        case .waitingForInitialPopupConfigure, .pendingInitialRolePayload:
            false
        case .waitingForPopupConfigure, .pendingRolePayload, .ready:
            true
        }
    }
}

private enum PopupConfigurePhase {
    case waitingForInitialPopupConfigure
    case pendingInitialRolePayload(RawXDGPopupConfigure)
    case waitingForPopupConfigure
    case pendingRolePayload(RawXDGPopupConfigure)
    case ready(PopupConfigureSequence)
    case failed(ClientError, recovery: PopupConfigureRecoverablePhase)
}

package final class PopupConfigureState {
    private var phase = PopupConfigurePhase.waitingForInitialPopupConfigure
    private var onSurfaceConfigure: (() -> Void)?

    package var hasReceivedInitialConfigure: Bool {
        recoverablePhase.hasReceivedInitialConfigure
    }

    /// Whether a complete surface configure is waiting to be consumed.
    package var hasPendingSurfaceConfigure: Bool {
        switch recoverablePhase {
        case .ready:
            true
        case .waitingForInitialPopupConfigure,
            .pendingInitialRolePayload,
            .waitingForPopupConfigure,
            .pendingRolePayload:
            false
        }
    }

    package init() {
        // Starts with no popup configure payload.
    }

    package func setSurfaceConfigureHandler(_ handler: @escaping () -> Void) {
        onSurfaceConfigure = handler
    }

    package func handlePopupConfigure(_ configure: RawXDGPopupConfigure) {
        if recoverablePhase.hasReceivedInitialConfigure {
            replaceRecoverablePhase(.pendingRolePayload(configure))
        } else {
            replaceRecoverablePhase(.pendingInitialRolePayload(configure))
        }
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
        let pendingConfigure: RawXDGPopupConfigure
        switch recoverablePhase {
        case .pendingInitialRolePayload(let configure),
            .pendingRolePayload(let configure):
            pendingConfigure = configure
        case .waitingForInitialPopupConfigure, .waitingForPopupConfigure, .ready:
            return .waitingForPopupConfigure
        }

        let placement: PopupPlacement
        do {
            placement = try PopupPlacement(configure: pendingConfigure)
        } catch let error as ClientError {
            recordError(error)
            return .failed(error)
        } catch let error as DomainValueError {
            let clientError = ClientError.domainValue(error)
            recordError(clientError)
            return .failed(clientError)
        } catch {
            let clientError = ClientError.invalidWindowState(
                .unexpectedPopupConfigureError(String(describing: error))
            )
            recordError(clientError)
            return .failed(clientError)
        }

        let configure = PopupConfigureSequence(serial: serial, placement: placement)
        replaceRecoverablePhase(.ready(configure))
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
        case .waitingForInitialPopupConfigure:
            .waitingForInitialPopupConfigure
        case .pendingInitialRolePayload(let configure):
            .pendingInitialRolePayload(configure)
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
        case .waitingForInitialPopupConfigure:
            phase = .waitingForInitialPopupConfigure
        case .pendingInitialRolePayload(let configure):
            phase = .pendingInitialRolePayload(configure)
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
