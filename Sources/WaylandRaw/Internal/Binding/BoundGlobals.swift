import CWaylandClientSystem
import CWaylandProtocols

package enum SupportedVersions {
    package static let wlCompositor: RawVersion = 6
    package static let wlShm: RawVersion = 1
    package static let wlOutput: RawVersion = 4
    package static let xdgWmBase: RawVersion = 7
    package static let zxdgDecorationManagerV1Minimum: RawVersion = 2
    package static let zxdgDecorationManagerV1: RawVersion = 2
    package static let zxdgOutputManagerV1Minimum: RawVersion = 2
    package static let zxdgOutputManagerV1: RawVersion = 3
    package static let wpViewporter: RawVersion = 1
    package static let wpPresentation: RawVersion = 2
    package static let wpFractionalScaleManagerV1: RawVersion = 1
    package static let wpCursorShapeManagerV1: RawVersion = 2
    package static let zwpLinuxDmabufV1: RawVersion = 5
    package static let wlSeat: RawVersion = 10
    package static let wlDataDeviceManager: RawVersion = 3
    package static let zwpPrimarySelectionDeviceManagerV1: RawVersion = 1
}

package enum XDGDecorationManagerBindingDecision: Equatable, Sendable {
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bind(version: RawVersion)
}

package enum XDGOutputManagerBindingDecision: Equatable, Sendable {
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bind(version: RawVersion)
}

package struct OptionalGlobals {
    package let xdgDecorationManager: OptionalXDGDecorationManager
    package let xdgOutputManager: OptionalXDGOutputManager
    package let viewporter: OptionalViewporter
    package let presentation: OptionalPresentation
    package let fractionalScaleManager: OptionalFractionalScaleManager
    package let cursorShapeManager: OptionalCursorShapeManager
    package let dataDeviceManager: OptionalDataDeviceManager
    package let primarySelectionDeviceManager: OptionalPrimarySelectionDeviceManager
    package let linuxDmabuf: OptionalLinuxDmabuf

    package init(
        xdgDecorationManager manager: OptionalXDGDecorationManager = .missing,
        xdgOutputManager boundXDGOutputManager: OptionalXDGOutputManager = .missing,
        viewporter boundViewporter: OptionalViewporter = .missing,
        presentation boundPresentation: OptionalPresentation = .missing,
        fractionalScaleManager boundFractionalScaleManager: OptionalFractionalScaleManager =
            .missing,
        cursorShapeManager boundCursorShapeManager: OptionalCursorShapeManager = .missing,
        dataDeviceManager boundDataDeviceManager: OptionalDataDeviceManager = .missing,
        primarySelectionDeviceManager boundPrimarySelectionDeviceManager:
            OptionalPrimarySelectionDeviceManager = .missing,
        linuxDmabuf boundLinuxDmabuf: OptionalLinuxDmabuf = .missing
    ) {
        xdgDecorationManager = manager
        xdgOutputManager = boundXDGOutputManager
        viewporter = boundViewporter
        presentation = boundPresentation
        fractionalScaleManager = boundFractionalScaleManager
        cursorShapeManager = boundCursorShapeManager
        dataDeviceManager = boundDataDeviceManager
        primarySelectionDeviceManager = boundPrimarySelectionDeviceManager
        linuxDmabuf = boundLinuxDmabuf
    }

    func destroy() {
        linuxDmabuf.destroy()
        primarySelectionDeviceManager.destroy()
        dataDeviceManager.destroy()
        cursorShapeManager.destroy()
        fractionalScaleManager.destroy()
        presentation.destroy()
        viewporter.destroy()
        xdgOutputManager.destroy()
        xdgDecorationManager.destroy()
    }

    package var supportsFractionalScaling: Bool {
        switch (viewporter, fractionalScaleManager) {
        case (.bound, .bound):
            true
        case (.missing, _),
            (_, .missing):
            false
        }
    }
}

package final class BoundGlobals {
    package let compositor: RawCompositor
    package let sharedMemory: RawSharedMemory
    package let xdgWMBase: RawXDGWMBase
    package let extensions: OptionalGlobals
    package let seatRegistry: SeatRegistry
    package let outputRegistry: OutputRegistry

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seatRegistry boundSeatRegistry: SeatRegistry,
        outputRegistry boundOutputRegistry: OutputRegistry,
        extensions boundExtensions: OptionalGlobals = OptionalGlobals()
    ) {
        compositor = boundCompositor
        sharedMemory = boundSharedMemory
        xdgWMBase = boundXDGWMBase
        seatRegistry = boundSeatRegistry
        outputRegistry = boundOutputRegistry
        extensions = boundExtensions
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        outputRegistry.destroy()
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
