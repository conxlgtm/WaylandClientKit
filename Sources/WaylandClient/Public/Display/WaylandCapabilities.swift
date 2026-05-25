import WaylandRaw

/// Whether SwiftWayland can use a compositor protocol feature.
public enum ProtocolAvailability: Equatable, Sendable {
    case unavailable
    case available(version: UInt32)

    /// True when the compositor advertised a compatible protocol version.
    public var isAvailable: Bool {
        switch self {
        case .unavailable:
            false
        case .available:
            true
        }
    }

    /// The negotiated protocol version SwiftWayland will use, when available.
    public var version: UInt32? {
        switch self {
        case .unavailable:
            nil
        case .available(let version):
            version
        }
    }
}

/// Protocol features advertised by the connected compositor.
public struct WaylandCapabilities: Equatable, Sendable {
    /// Regular clipboard support through `wl_data_device_manager`.
    public let clipboard: ProtocolAvailability

    /// Drag-and-drop target/source support through `wl_data_device_manager`.
    public let dragAndDrop: ProtocolAvailability

    /// Drag-and-drop action negotiation through `wl_data_device_manager` v3.
    public let dragActionNegotiation: ProtocolAvailability

    /// Primary selection support through `zwp_primary_selection_device_manager_v1`.
    public let primarySelection: ProtocolAvailability

    /// Server-side decoration support through `zxdg_decoration_manager_v1`.
    public let xdgDecoration: ProtocolAvailability

    /// Desktop logical output geometry support through `zxdg_output_manager_v1`.
    public let xdgOutput: ProtocolAvailability

    /// Surface cropping and scaling support through `wp_viewporter`.
    public let viewporter: ProtocolAvailability

    /// Compositor presentation feedback through `wp_presentation`.
    public let presentationTime: ProtocolAvailability

    /// Fractional surface scale support through `wp_fractional_scale_manager_v1`.
    public let fractionalScale: ProtocolAvailability

    /// Compositor-managed pointer cursor shapes through `wp_cursor_shape_manager_v1`.
    public let cursorShape: ProtocolAvailability

    /// Desktop activation token support through `xdg_activation_v1`.
    public let xdgActivation: ProtocolAvailability

    /// Compositor/IME text entry support through `zwp_text_input_manager_v3`.
    public let textInput: ProtocolAvailability

    /// Dmabuf buffer sharing support through `zwp_linux_dmabuf_v1`.
    public let linuxDmabuf: ProtocolAvailability

    public init(
        clipboard: ProtocolAvailability,
        dragAndDrop: ProtocolAvailability,
        dragActionNegotiation: ProtocolAvailability,
        primarySelection: ProtocolAvailability,
        xdgDecoration: ProtocolAvailability,
        xdgOutput: ProtocolAvailability,
        viewporter: ProtocolAvailability,
        presentationTime: ProtocolAvailability,
        fractionalScale: ProtocolAvailability,
        cursorShape: ProtocolAvailability,
        xdgActivation: ProtocolAvailability,
        textInput: ProtocolAvailability,
        linuxDmabuf: ProtocolAvailability
    ) {
        self.clipboard = clipboard
        self.dragAndDrop = dragAndDrop
        self.dragActionNegotiation = dragActionNegotiation
        self.primarySelection = primarySelection
        self.xdgDecoration = xdgDecoration
        self.xdgOutput = xdgOutput
        self.viewporter = viewporter
        self.presentationTime = presentationTime
        self.fractionalScale = fractionalScale
        self.cursorShape = cursorShape
        self.xdgActivation = xdgActivation
        self.textInput = textInput
        self.linuxDmabuf = linuxDmabuf
    }

    public init(
        clipboard: ProtocolAvailability,
        dragAndDrop: ProtocolAvailability,
        dragActionNegotiation: ProtocolAvailability,
        primarySelection: ProtocolAvailability,
        xdgDecoration: ProtocolAvailability,
        xdgOutput: ProtocolAvailability,
        viewporter: ProtocolAvailability,
        presentationTime: ProtocolAvailability,
        fractionalScale: ProtocolAvailability,
        cursorShape: ProtocolAvailability,
        textInput: ProtocolAvailability,
        linuxDmabuf: ProtocolAvailability
    ) {
        self.init(
            clipboard: clipboard,
            dragAndDrop: dragAndDrop,
            dragActionNegotiation: dragActionNegotiation,
            primarySelection: primarySelection,
            xdgDecoration: xdgDecoration,
            xdgOutput: xdgOutput,
            viewporter: viewporter,
            presentationTime: presentationTime,
            fractionalScale: fractionalScale,
            cursorShape: cursorShape,
            xdgActivation: .unavailable,
            textInput: textInput,
            linuxDmabuf: linuxDmabuf
        )
    }
}

struct AdvertisedWaylandProtocol: Equatable, Sendable {
    let interfaceName: String
    let advertisedVersion: UInt32
}

extension WaylandCapabilities {
    // swiftlint:disable:next function_body_length
    static func fromAdvertisedProtocols(
        _ protocols: [AdvertisedWaylandProtocol]
    ) -> WaylandCapabilities {
        return WaylandCapabilities(
            clipboard: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "wl_data_device_manager"),
                supportedByClient: SupportedVersions.wlDataDeviceManager
            ),
            dragAndDrop: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "wl_data_device_manager"),
                supportedByClient: SupportedVersions.wlDataDeviceManager
            ),
            dragActionNegotiation: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "wl_data_device_manager"),
                supportedByClient: SupportedVersions.wlDataDeviceManager,
                minimumVersion: 3
            ),
            primarySelection: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(
                    named: "zwp_primary_selection_device_manager_v1"
                ),
                supportedByClient: SupportedVersions.zwpPrimarySelectionDeviceManagerV1
            ),
            xdgDecoration: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "zxdg_decoration_manager_v1"),
                supportedByClient: SupportedVersions.zxdgDecorationManagerV1,
                minimumVersion: SupportedVersions.zxdgDecorationManagerV1Minimum
            ),
            xdgOutput: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "zxdg_output_manager_v1"),
                supportedByClient: SupportedVersions.zxdgOutputManagerV1,
                minimumVersion: SupportedVersions.zxdgOutputManagerV1Minimum
            ),
            viewporter: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "wp_viewporter"),
                supportedByClient: SupportedVersions.wpViewporter
            ),
            presentationTime: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "wp_presentation"),
                supportedByClient: SupportedVersions.wpPresentation
            ),
            fractionalScale: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(
                    named: "wp_fractional_scale_manager_v1"
                ),
                supportedByClient: SupportedVersions.wpFractionalScaleManagerV1
            ),
            cursorShape: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "wp_cursor_shape_manager_v1"),
                supportedByClient: SupportedVersions.wpCursorShapeManagerV1
            ),
            xdgActivation: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "xdg_activation_v1"),
                supportedByClient: SupportedVersions.xdgActivationV1
            ),
            textInput: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "zwp_text_input_manager_v3"),
                supportedByClient: SupportedVersions.zwpTextInputManagerV3
            ),
            linuxDmabuf: ProtocolAvailability(
                protocols.bestAdvertisedProtocol(named: "zwp_linux_dmabuf_v1"),
                supportedByClient: SupportedVersions.zwpLinuxDmabufV1
            )
        )
    }
}

extension Sequence where Element == AdvertisedWaylandProtocol {
    func bestAdvertisedProtocol(named interfaceName: String) -> AdvertisedWaylandProtocol? {
        var selected: AdvertisedWaylandProtocol?
        for advertisedProtocol in self
        where advertisedProtocol.interfaceName == interfaceName {
            guard let current = selected else {
                selected = advertisedProtocol
                continue
            }

            if advertisedProtocol.advertisedVersion > current.advertisedVersion {
                selected = advertisedProtocol
            }
        }

        return selected
    }
}

extension ProtocolAvailability {
    init(
        _ advertisedProtocol: AdvertisedWaylandProtocol?,
        supportedByClient clientSupportedVersion: RawVersion,
        minimumVersion: RawVersion? = nil
    ) {
        guard let advertisedProtocol else {
            self = .unavailable
            return
        }

        let advertisedVersion = RawVersion(advertisedProtocol.advertisedVersion)
        if let minimumVersion, advertisedVersion < minimumVersion {
            self = .unavailable
            return
        }

        let negotiatedVersion = Swift.min(advertisedVersion, clientSupportedVersion)
        self = .available(version: negotiatedVersion.value)
    }
}
