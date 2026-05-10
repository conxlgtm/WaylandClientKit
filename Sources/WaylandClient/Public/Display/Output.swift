import WaylandRaw

public struct OutputID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue outputRawValue: UInt32) {
        rawValue = outputRawValue
    }

    public var description: String {
        "output-\(rawValue)"
    }
}

public enum OutputSubpixelLayout: Equatable, Sendable {
    case unknown
    case none
    case horizontalRGB
    case horizontalBGR
    case verticalRGB
    case verticalBGR
    case unrecognized(Int32)

    public init(rawValue outputRawValue: Int32) {
        switch outputRawValue {
        case 0:
            self = .unknown
        case 1:
            self = .none
        case 2:
            self = .horizontalRGB
        case 3:
            self = .horizontalBGR
        case 4:
            self = .verticalRGB
        case 5:
            self = .verticalBGR
        default:
            self = .unrecognized(outputRawValue)
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .unknown:
            0
        case .none:
            1
        case .horizontalRGB:
            2
        case .horizontalBGR:
            3
        case .verticalRGB:
            4
        case .verticalBGR:
            5
        case .unrecognized(let rawValue):
            rawValue
        }
    }
}

public enum OutputTransform: Equatable, Sendable {
    case normal
    case rotated90
    case rotated180
    case rotated270
    case flipped
    case flipped90
    case flipped180
    case flipped270
    case unrecognized(Int32)

    public init(rawValue outputRawValue: Int32) {
        switch outputRawValue {
        case 0:
            self = .normal
        case 1:
            self = .rotated90
        case 2:
            self = .rotated180
        case 3:
            self = .rotated270
        case 4:
            self = .flipped
        case 5:
            self = .flipped90
        case 6:
            self = .flipped180
        case 7:
            self = .flipped270
        default:
            self = .unrecognized(outputRawValue)
        }
    }

    public var rawValue: Int32 {
        switch self {
        case .normal:
            0
        case .rotated90:
            1
        case .rotated180:
            2
        case .rotated270:
            3
        case .flipped:
            4
        case .flipped90:
            5
        case .flipped180:
            6
        case .flipped270:
            7
        case .unrecognized(let rawValue):
            rawValue
        }
    }
}

public struct OutputGeometry: Equatable, Sendable {
    public let x: Int32
    public let y: Int32
    public let physicalWidthMillimeters: Int32
    public let physicalHeightMillimeters: Int32
    public let subpixel: OutputSubpixelLayout
    public let make: String?
    public let model: String?
    public let transform: OutputTransform

    public init(
        x geometryX: Int32,
        y geometryY: Int32,
        physicalWidthMillimeters geometryPhysicalWidthMillimeters: Int32,
        physicalHeightMillimeters geometryPhysicalHeightMillimeters: Int32,
        subpixel geometrySubpixel: OutputSubpixelLayout,
        make geometryMake: String?,
        model geometryModel: String?,
        transform geometryTransform: OutputTransform
    ) {
        x = geometryX
        y = geometryY
        physicalWidthMillimeters = geometryPhysicalWidthMillimeters
        physicalHeightMillimeters = geometryPhysicalHeightMillimeters
        subpixel = geometrySubpixel
        make = geometryMake
        model = geometryModel
        transform = geometryTransform
    }
}

public struct OutputModeFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue modeRawValue: UInt32) {
        rawValue = modeRawValue
    }

    public static let current = OutputModeFlags(rawValue: 0x1)
    public static let preferred = OutputModeFlags(rawValue: 0x2)
}

public struct OutputMode: Equatable, Sendable {
    public let flags: OutputModeFlags
    public let width: Int32
    public let height: Int32
    public let refreshMilliHertz: Int32

    public init(
        flags modeFlags: OutputModeFlags,
        width modeWidth: Int32,
        height modeHeight: Int32,
        refreshMilliHertz modeRefreshMilliHertz: Int32
    ) {
        flags = modeFlags
        width = modeWidth
        height = modeHeight
        refreshMilliHertz = modeRefreshMilliHertz
    }
}

public struct OutputLogicalGeometry: Equatable, Sendable {
    public let x: Int32
    public let y: Int32
    public let width: PositiveInt32
    public let height: PositiveInt32

    public init(
        x geometryX: Int32,
        y geometryY: Int32,
        width geometryWidth: PositiveInt32,
        height geometryHeight: PositiveInt32
    ) {
        x = geometryX
        y = geometryY
        width = geometryWidth
        height = geometryHeight
    }
}

public struct OutputSnapshot: Equatable, Sendable {
    public let id: OutputID
    public let version: UInt32
    public let geometry: OutputGeometry?
    public let logicalGeometry: OutputLogicalGeometry?
    public let currentMode: OutputMode?
    public let scale: PositiveInt32
    public let name: String?
    public let description: String?

    public init(
        id outputID: OutputID,
        version outputVersion: UInt32,
        geometry outputGeometry: OutputGeometry?,
        logicalGeometry outputLogicalGeometry: OutputLogicalGeometry?,
        currentMode outputCurrentMode: OutputMode?,
        scale outputScale: PositiveInt32,
        name outputName: String?,
        description outputDescription: String?
    ) {
        id = outputID
        version = outputVersion
        geometry = outputGeometry
        logicalGeometry = outputLogicalGeometry
        currentMode = outputCurrentMode
        scale = outputScale
        name = outputName
        description = outputDescription
    }

    package init(_ raw: RawOutputSnapshot) {
        self.init(
            id: OutputID(rawValue: raw.id.rawValue),
            version: raw.version.value,
            geometry: raw.geometry.map(OutputGeometry.init),
            logicalGeometry: raw.logicalGeometry.map(OutputLogicalGeometry.init),
            currentMode: raw.currentMode.map(OutputMode.init),
            scale: PositiveInt32(unchecked: raw.scale),
            name: raw.name,
            description: raw.description
        )
    }
}

extension OutputGeometry {
    package init(_ raw: RawOutputGeometry) {
        self.init(
            x: raw.x,
            y: raw.y,
            physicalWidthMillimeters: raw.physicalWidthMillimeters,
            physicalHeightMillimeters: raw.physicalHeightMillimeters,
            subpixel: OutputSubpixelLayout(rawValue: raw.subpixel),
            make: raw.make,
            model: raw.model,
            transform: OutputTransform(rawValue: raw.transform)
        )
    }
}

extension OutputLogicalGeometry {
    package init(_ raw: RawOutputLogicalGeometry) {
        self.init(
            x: raw.x,
            y: raw.y,
            width: PositiveInt32(unchecked: raw.width),
            height: PositiveInt32(unchecked: raw.height)
        )
    }
}

extension OutputMode {
    package init(_ raw: RawOutputMode) {
        self.init(
            flags: OutputModeFlags(rawValue: raw.flags),
            width: raw.width,
            height: raw.height,
            refreshMilliHertz: raw.refreshMilliHertz
        )
    }
}
