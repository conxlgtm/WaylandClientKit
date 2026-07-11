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
    package static let xdgSessionManagerV1: RawVersion = 1
    package static let xdgToplevelIconManagerV1: RawVersion = 1
    package static let xdgSystemBellV1: RawVersion = 1
    package static let xdgWmDialogV1: RawVersion = 1
    package static let xdgToplevelDragManagerV1: RawVersion = 1
    package static let extForeignToplevelListV1: RawVersion = 1
    package static let wpPointerWarpV1: RawVersion = 1
    package static let zwpTabletManagerV2: RawVersion = 2
    package static let zwpRelativePointerManagerV1: RawVersion = 1
    package static let zwpPointerConstraintsV1: RawVersion = 1
    package static let zwpPointerGesturesV1: RawVersion = 3
    package static let zwpKeyboardShortcutsInhibitManagerV1: RawVersion = 1
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
    package static let zwlrOutputManagerV1: RawVersion = 4
}

package enum XDGDecorationManagerBindingDecision: Equatable, Sendable {
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bind(version: RawVersion)
}

package enum XDGOutputManagerBindingDecision: Equatable, Sendable {
    case unsupportedVersion(advertised: RawVersion, minimum: RawVersion)
    case bind(version: RawVersion)
}

package final class OptionalGlobals {
    package private(set) var xdgDecorationManager: OptionalXDGDecorationManager
    package private(set) var xdgOutputManager: OptionalXDGOutputManager
    package private(set) var viewporter: OptionalViewporter
    package private(set) var presentation: OptionalPresentation
    package private(set) var fractionalScaleManager: OptionalFractionalScaleManager
    package private(set) var cursorShapeManager: OptionalCursorShapeManager
    package private(set) var xdgToplevelIconManager: OptionalXDGToplevelIconManager
    package private(set) var xdgActivation: OptionalXDGActivation
    package private(set) var compositorSessionManager: OptionalCompositorSessionManager
    package private(set) var pointerWarp: OptionalPointerWarp
    package private(set) var tabletManager: OptionalTabletManager
    package private(set) var relativePointerManager: OptionalRelativePointerManager
    package private(set) var pointerConstraints: OptionalPointerConstraints
    package private(set) var linuxDrmSyncobjManager: OptionalLinuxDrmSyncobjManager
    package private(set) var fifoManager: OptionalFifoManager
    package private(set) var commitTimingManager: OptionalCommitTimingManager
    package private(set) var contentTypeManager: OptionalContentTypeManager
    package private(set) var alphaModifierManager: OptionalAlphaModifierManager
    package private(set) var tearingControlManager: OptionalTearingControlManager
    package private(set) var colorRepresentationManager: OptionalColorRepresentationManager
    package private(set) var colorManager: OptionalColorManager
    package private(set) var dataDeviceManager: OptionalDataDeviceManager
    package private(set) var primarySelectionDeviceManager: OptionalPrimarySelectionDeviceManager
    package private(set) var textInputManager: OptionalTextInputManager
    package private(set) var linuxDmabuf: OptionalLinuxDmabuf

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
        compositorSessionManager boundCompositorSessionManager:
            OptionalCompositorSessionManager = .missing,
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
        compositorSessionManager = boundCompositorSessionManager
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
        compositorSessionManager.destroy()
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

    // swiftlint:disable:next cyclomatic_complexity
    package func invalidate(named interfaceName: String) {
        switch interfaceName {
        case "zxdg_decoration_manager_v1": retireOptionalGlobal(&xdgDecorationManager)
        case "zxdg_output_manager_v1": retireOptionalGlobal(&xdgOutputManager)
        case "wp_viewporter": retireOptionalGlobal(&viewporter)
        case "wp_presentation": retireOptionalGlobal(&presentation)
        case "wp_fractional_scale_manager_v1": retireOptionalGlobal(&fractionalScaleManager)
        case "wp_cursor_shape_manager_v1": retireOptionalGlobal(&cursorShapeManager)
        case "xdg_toplevel_icon_manager_v1": retireOptionalGlobal(&xdgToplevelIconManager)
        case "xdg_activation_v1": retireOptionalGlobal(&xdgActivation)
        case "xdg_session_manager_v1": retireOptionalGlobal(&compositorSessionManager)
        case "wp_pointer_warp_v1": retireOptionalGlobal(&pointerWarp)
        case "zwp_tablet_manager_v2": retireOptionalGlobal(&tabletManager)
        case "zwp_relative_pointer_manager_v1": retireOptionalGlobal(&relativePointerManager)
        case "zwp_pointer_constraints_v1": retireOptionalGlobal(&pointerConstraints)
        case "wp_linux_drm_syncobj_manager_v1": retireOptionalGlobal(&linuxDrmSyncobjManager)
        case "wp_fifo_manager_v1": retireOptionalGlobal(&fifoManager)
        case "wp_commit_timing_manager_v1": retireOptionalGlobal(&commitTimingManager)
        case "wp_content_type_manager_v1": retireOptionalGlobal(&contentTypeManager)
        case "wp_alpha_modifier_v1": retireOptionalGlobal(&alphaModifierManager)
        case "wp_tearing_control_manager_v1": retireOptionalGlobal(&tearingControlManager)
        case "wp_color_representation_manager_v1":
            retireOptionalGlobal(&colorRepresentationManager)
        case "wp_color_manager_v1": retireOptionalGlobal(&colorManager)
        case "wl_data_device_manager": retireOptionalGlobal(&dataDeviceManager)
        case "zwp_primary_selection_device_manager_v1":
            retireOptionalGlobal(&primarySelectionDeviceManager)
        case "zwp_text_input_manager_v3": retireOptionalGlobal(&textInputManager)
        case "zwp_linux_dmabuf_v1": retireOptionalGlobal(&linuxDmabuf)
        default: break
        }
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
    package private(set) var tabletSeatRegistry: TabletSeatRegistry?
    package let outputRegistry: OutputRegistry

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seatRegistry boundSeatRegistry: SeatRegistry,
        outputRegistry boundOutputRegistry: OutputRegistry,
        extensions boundExtensions: OptionalGlobals = OptionalGlobals(),
        tabletSeatRegistry boundTabletSeatRegistry: TabletSeatRegistry? = nil
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

    package func invalidateOptionalGlobal(named interfaceName: String) {
        if interfaceName == "zxdg_output_manager_v1" {
            outputRegistry.invalidateXDGOutputManager()
        }
        if interfaceName == "zwp_tablet_manager_v2" {
            tabletSeatRegistry?.destroy()
            tabletSeatRegistry = nil
        }
        extensions.invalidate(named: interfaceName)
    }

    deinit {
        destroy()
    }
}
