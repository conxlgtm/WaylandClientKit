import CWaylandClientSystem
import CWaylandProtocols

package enum SupportedVersions {
    package static let wlCompositor: RawVersion = 6
    package static let wlSubcompositor: RawVersion = 1
    package static let wlShm: RawVersion = 1
    package static let wlOutput: RawVersion = 4
    package static let xdgWmBase: RawVersion = 7
    package static let zxdgDecorationManagerV1Minimum: RawVersion = 1
    package static let zxdgDecorationManagerV1: RawVersion = 2
    package static let zxdgOutputManagerV1Minimum: RawVersion = 2
    package static let zxdgOutputManagerV1: RawVersion = 3
    package static let wpViewporter: RawVersion = 1
    package static let wpPresentation: RawVersion = 2
    package static let wpFractionalScaleManagerV1: RawVersion = 1
    package static let wpCursorShapeManagerV1: RawVersion = 2
    package static let xdgActivationV1: RawVersion = 1
    package static let xdgToplevelIconManagerV1: RawVersion = 1
    package static let xdgSystemBellV1: RawVersion = 1
    package static let wpPointerWarpV1: RawVersion = 1
    package static let zwpTabletManagerV2: RawVersion = 2
    package static let zwpRelativePointerManagerV1: RawVersion = 1
    package static let zwpPointerConstraintsV1: RawVersion = 1
    package static let zwpIdleInhibitManagerV1: RawVersion = 1
    package static let wpLinuxDrmSyncobjManagerV1: RawVersion = 1
    package static let wpFifoManagerV1: RawVersion = 1
    package static let wpCommitTimingManagerV1: RawVersion = 1
    package static let wpContentTypeManagerV1: RawVersion = 1
    package static let wpAlphaModifierV1: RawVersion = 1
    package static let wpTearingControlManagerV1: RawVersion = 1
    package static let wpColorRepresentationManagerV1: RawVersion = 1
    package static let wpColorManagerV1: RawVersion = 2
    package static let zwpLinuxDmabufV1: RawVersion = 5
    package static let wlSeat: RawVersion = 10
    package static let wlDataDeviceManager: RawVersion = 3
    package static let zwpPrimarySelectionDeviceManagerV1: RawVersion = 1
    package static let zwpTextInputManagerV3: RawVersion = 2
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
    package let xdgToplevelIconManager: OptionalXDGToplevelIconManager
    package let xdgActivation: OptionalXDGActivation
    package let pointerWarp: OptionalPointerWarp
    package let tabletManager: OptionalTabletManager
    package let relativePointerManager: OptionalRelativePointerManager
    package let pointerConstraints: OptionalPointerConstraints
    package let linuxDrmSyncobjManager: OptionalLinuxDrmSyncobjManager
    package let fifoManager: OptionalFifoManager
    package let commitTimingManager: OptionalCommitTimingManager
    package let contentTypeManager: OptionalContentTypeManager
    package let alphaModifierManager: OptionalAlphaModifierManager
    package let tearingControlManager: OptionalTearingControlManager
    package let colorRepresentationManager: OptionalColorRepresentationManager
    package let colorManager: OptionalColorManager
    package let dataDeviceManager: OptionalDataDeviceManager
    package let primarySelectionDeviceManager: OptionalPrimarySelectionDeviceManager
    package let textInputManager: OptionalTextInputManager
    package let linuxDmabuf: OptionalLinuxDmabuf

    package init(
        xdgDecorationManager manager: OptionalXDGDecorationManager = .missing,
        xdgOutputManager boundXDGOutputManager: OptionalXDGOutputManager = .missing,
        viewporter boundViewporter: OptionalViewporter = .missing,
        presentation boundPresentation: OptionalPresentation = .missing,
        fractionalScaleManager boundFractionalScaleManager: OptionalFractionalScaleManager =
            .missing,
        cursorShapeManager boundCursorShapeManager: OptionalCursorShapeManager = .missing,
        xdgToplevelIconManager boundXDGToplevelIconManager:
            OptionalXDGToplevelIconManager = .missing,
        xdgActivation boundXDGActivation: OptionalXDGActivation = .missing,
        pointerWarp boundPointerWarp: OptionalPointerWarp = .missing,
        tabletManager boundTabletManager: OptionalTabletManager = .missing,
        relativePointerManager boundRelativePointerManager: OptionalRelativePointerManager =
            .missing,
        pointerConstraints boundPointerConstraints: OptionalPointerConstraints = .missing,
        linuxDrmSyncobjManager boundLinuxDrmSyncobjManager:
            OptionalLinuxDrmSyncobjManager = .missing,
        fifoManager boundFifoManager: OptionalFifoManager = .missing,
        commitTimingManager boundCommitTimingManager: OptionalCommitTimingManager = .missing,
        contentTypeManager boundContentTypeManager: OptionalContentTypeManager = .missing,
        alphaModifierManager boundAlphaModifierManager: OptionalAlphaModifierManager =
            .missing,
        tearingControlManager boundTearingControlManager:
            OptionalTearingControlManager = .missing,
        colorRepresentationManager boundColorRepresentationManager:
            OptionalColorRepresentationManager = .missing,
        colorManager boundColorManager: OptionalColorManager = .missing,
        dataDeviceManager boundDataDeviceManager: OptionalDataDeviceManager = .missing,
        primarySelectionDeviceManager boundPrimarySelectionDeviceManager:
            OptionalPrimarySelectionDeviceManager = .missing,
        textInputManager boundTextInputManager: OptionalTextInputManager = .missing,
        linuxDmabuf boundLinuxDmabuf: OptionalLinuxDmabuf = .missing
    ) {
        xdgDecorationManager = manager
        xdgOutputManager = boundXDGOutputManager
        viewporter = boundViewporter
        presentation = boundPresentation
        fractionalScaleManager = boundFractionalScaleManager
        cursorShapeManager = boundCursorShapeManager
        xdgToplevelIconManager = boundXDGToplevelIconManager
        xdgActivation = boundXDGActivation
        pointerWarp = boundPointerWarp
        tabletManager = boundTabletManager
        relativePointerManager = boundRelativePointerManager
        pointerConstraints = boundPointerConstraints
        linuxDrmSyncobjManager = boundLinuxDrmSyncobjManager
        fifoManager = boundFifoManager
        commitTimingManager = boundCommitTimingManager
        contentTypeManager = boundContentTypeManager
        alphaModifierManager = boundAlphaModifierManager
        tearingControlManager = boundTearingControlManager
        colorRepresentationManager = boundColorRepresentationManager
        colorManager = boundColorManager
        dataDeviceManager = boundDataDeviceManager
        primarySelectionDeviceManager = boundPrimarySelectionDeviceManager
        textInputManager = boundTextInputManager
        linuxDmabuf = boundLinuxDmabuf
    }

    func destroy() {
        colorManager.destroy()
        colorRepresentationManager.destroy()
        tearingControlManager.destroy()
        alphaModifierManager.destroy()
        contentTypeManager.destroy()
        linuxDmabuf.destroy()
        commitTimingManager.destroy()
        fifoManager.destroy()
        linuxDrmSyncobjManager.destroy()
        pointerConstraints.destroy()
        relativePointerManager.destroy()
        tabletManager.destroy()
        pointerWarp.destroy()
        xdgActivation.destroy()
        xdgToplevelIconManager.destroy()
        textInputManager.destroy()
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
    package let tabletSeatRegistry: TabletSeatRegistry?
    package let outputRegistry: OutputRegistry

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seatRegistry boundSeatRegistry: SeatRegistry,
        tabletSeatRegistry boundTabletSeatRegistry: TabletSeatRegistry? = nil,
        outputRegistry boundOutputRegistry: OutputRegistry,
        extensions boundExtensions: OptionalGlobals = OptionalGlobals()
    ) {
        compositor = boundCompositor
        sharedMemory = boundSharedMemory
        xdgWMBase = boundXDGWMBase
        seatRegistry = boundSeatRegistry
        tabletSeatRegistry = boundTabletSeatRegistry
        outputRegistry = boundOutputRegistry
        extensions = boundExtensions
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        outputRegistry.destroy()
        tabletSeatRegistry?.destroy()
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
