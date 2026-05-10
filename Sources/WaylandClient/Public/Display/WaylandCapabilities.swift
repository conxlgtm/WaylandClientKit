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

    /// Primary selection support through `zwp_primary_selection_device_manager_v1`.
    public let primarySelection: ProtocolAvailability

    /// Server-side decoration support through `zxdg_decoration_manager_v1`.
    public let xdgDecoration: ProtocolAvailability

    /// Desktop logical output geometry support through `zxdg_output_manager_v1`.
    public let xdgOutput: ProtocolAvailability

    /// Surface cropping and scaling support through `wp_viewporter`.
    public let viewporter: ProtocolAvailability

    /// Fractional surface scale support through `wp_fractional_scale_manager_v1`.
    public let fractionalScale: ProtocolAvailability

    public init(
        clipboard: ProtocolAvailability,
        primarySelection: ProtocolAvailability,
        xdgDecoration: ProtocolAvailability,
        xdgOutput: ProtocolAvailability,
        viewporter: ProtocolAvailability,
        fractionalScale: ProtocolAvailability
    ) {
        self.clipboard = clipboard
        self.primarySelection = primarySelection
        self.xdgDecoration = xdgDecoration
        self.xdgOutput = xdgOutput
        self.viewporter = viewporter
        self.fractionalScale = fractionalScale
    }
}

struct AdvertisedWaylandProtocol: Equatable, Sendable {
    let interfaceName: String
    let advertisedVersion: UInt32
}

extension WaylandCapabilities {
    static func fromAdvertisedProtocols(
        _ protocols: [AdvertisedWaylandProtocol]
    ) -> WaylandCapabilities {
        func first(_ interfaceName: String) -> AdvertisedWaylandProtocol? {
            protocols.first { $0.interfaceName == interfaceName }
        }

        return WaylandCapabilities(
            clipboard: ProtocolAvailability(
                first("wl_data_device_manager"),
                supportedByClient: SupportedVersions.wlDataDeviceManager
            ),
            primarySelection: ProtocolAvailability(
                first("zwp_primary_selection_device_manager_v1"),
                supportedByClient: SupportedVersions.zwpPrimarySelectionDeviceManagerV1
            ),
            xdgDecoration: ProtocolAvailability(
                first("zxdg_decoration_manager_v1"),
                supportedByClient: SupportedVersions.zxdgDecorationManagerV1,
                minimumVersion: SupportedVersions.zxdgDecorationManagerV1Minimum
            ),
            xdgOutput: ProtocolAvailability(
                first("zxdg_output_manager_v1"),
                supportedByClient: SupportedVersions.zxdgOutputManagerV1,
                minimumVersion: SupportedVersions.zxdgOutputManagerV1Minimum
            ),
            viewporter: ProtocolAvailability(
                first("wp_viewporter"),
                supportedByClient: SupportedVersions.wpViewporter
            ),
            fractionalScale: ProtocolAvailability(
                first("wp_fractional_scale_manager_v1"),
                supportedByClient: SupportedVersions.wpFractionalScaleManagerV1
            )
        )
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
