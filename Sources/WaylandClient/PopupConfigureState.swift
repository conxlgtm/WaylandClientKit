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

package final class PopupConfigureState {
    private var pendingConfigure: RawXDGPopupConfigure?
    private var latestConfigure: PopupConfigureSequence?
    private var pendingError: ClientError?
    private var onSurfaceConfigure: (() -> Void)?

    package private(set) var hasReceivedInitialConfigure = false

    package init() {
        // Starts with no popup configure payload.
    }

    package func setSurfaceConfigureHandler(_ handler: @escaping () -> Void) {
        onSurfaceConfigure = handler
    }

    package func handlePopupConfigure(_ configure: RawXDGPopupConfigure) {
        pendingConfigure = configure
    }

    package func recordError(_ error: ClientError) {
        if pendingError == nil {
            pendingError = error
        }
    }

    package func throwPendingErrorIfAny() throws {
        guard let error = pendingError else { return }

        pendingError = nil
        throw error
    }

    @discardableResult
    package func handleSurfaceConfigure(serial: UInt32) -> PopupSurfaceConfigureResult {
        guard let pendingConfigure else {
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
        self.pendingConfigure = nil
        latestConfigure = configure
        hasReceivedInitialConfigure = true
        onSurfaceConfigure?()
        return .configured(configure)
    }

    package func consumeLatestConfigure() -> PopupConfigureSequence? {
        defer {
            latestConfigure = nil
        }

        return latestConfigure
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
