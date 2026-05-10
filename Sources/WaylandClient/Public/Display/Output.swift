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

public struct OutputGeometry: Equatable, Sendable {
    public let x: Int32
    public let y: Int32
    public let physicalWidthMillimeters: Int32
    public let physicalHeightMillimeters: Int32
    public let subpixel: Int32
    public let make: String?
    public let model: String?
    public let transform: Int32

    public init(
        x geometryX: Int32,
        y geometryY: Int32,
        physicalWidthMillimeters geometryPhysicalWidthMillimeters: Int32,
        physicalHeightMillimeters geometryPhysicalHeightMillimeters: Int32,
        subpixel geometrySubpixel: Int32,
        make geometryMake: String?,
        model geometryModel: String?,
        transform geometryTransform: Int32
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

public struct OutputMode: Equatable, Sendable {
    public let flags: UInt32
    public let width: Int32
    public let height: Int32
    public let refreshMilliHertz: Int32

    public init(
        flags modeFlags: UInt32,
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

public struct OutputSnapshot: Equatable, Sendable {
    public let id: OutputID
    public let version: UInt32
    public let geometry: OutputGeometry?
    public let currentMode: OutputMode?
    public let scale: PositiveInt32
    public let name: String?
    public let description: String?

    public init(
        id outputID: OutputID,
        version outputVersion: UInt32,
        geometry outputGeometry: OutputGeometry?,
        currentMode outputCurrentMode: OutputMode?,
        scale outputScale: PositiveInt32,
        name outputName: String?,
        description outputDescription: String?
    ) {
        id = outputID
        version = outputVersion
        geometry = outputGeometry
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
            subpixel: raw.subpixel,
            make: raw.make,
            model: raw.model,
            transform: raw.transform
        )
    }
}

extension OutputMode {
    package init(_ raw: RawOutputMode) {
        self.init(
            flags: raw.flags,
            width: raw.width,
            height: raw.height,
            refreshMilliHertz: raw.refreshMilliHertz
        )
    }
}
