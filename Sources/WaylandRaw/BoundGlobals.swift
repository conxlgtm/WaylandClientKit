import CWaylandClientSystem
import CWaylandProtocols

package enum SupportedVersions {
    package static let wlCompositor: RawVersion = 6
    package static let wlShm: RawVersion = 1
    package static let xdgWmBase: RawVersion = 7
    package static let zxdgDecorationManagerV1Minimum: RawVersion = 2
    package static let zxdgDecorationManagerV1: RawVersion = 2
    package static let wlSeat: RawVersion = 10
}

package enum XDGDecorationManagerBindingDecision: Equatable, Sendable {
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bind(version: RawVersion)
}

package enum OptionalXDGDecorationManager {
    case missing
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bound(RawXDGDecorationManager)

    func destroy() {
        guard case .bound(let manager) = self else { return }

        manager.destroy()
    }
}

package struct OptionalGlobals {
    package let xdgDecorationManager: OptionalXDGDecorationManager

    package init(
        xdgDecorationManager manager: OptionalXDGDecorationManager = .missing
    ) {
        xdgDecorationManager = manager
    }

    func destroy() {
        xdgDecorationManager.destroy()
    }
}

package final class BoundGlobals {
    package let compositor: RawCompositor
    package let sharedMemory: RawSharedMemory
    package let xdgWMBase: RawXDGWMBase
    package let extensions: OptionalGlobals
    package let seatRegistry: SeatRegistry

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seatRegistry boundSeatRegistry: SeatRegistry,
        extensions boundExtensions: OptionalGlobals = OptionalGlobals()
    ) {
        compositor = boundCompositor
        sharedMemory = boundSharedMemory
        xdgWMBase = boundXDGWMBase
        seatRegistry = boundSeatRegistry
        extensions = boundExtensions
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        seatRegistry.destroy()
        extensions.destroy()
        xdgWMBase.destroy()
        sharedMemory.destroy()
        compositor.destroy()
    }

    deinit {
        destroy()
    }
}
