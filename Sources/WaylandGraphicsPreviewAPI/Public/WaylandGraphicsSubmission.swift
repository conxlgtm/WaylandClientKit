import Glibc
import WaylandClient
import WaylandGPUPreview
import WaylandRaw

// swiftlint:disable file_length

public struct WaylandGraphicsConfiguration: Equatable, Sendable {
    public var presentationMode: WaylandGraphicsPresentationMode
    public var fallbackPolicy: WaylandGraphicsFallbackPolicy
    public var backingPreference: WaylandGraphicsBackingKind {
        get {
            presentationMode.backingPreference
        }
        set {
            presentationMode = WaylandGraphicsPresentationMode(
                backingPreference: newValue,
                fallbackPolicy: fallbackPolicy
            )
        }
    }
    public var synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    public var pacingPolicy: WaylandGraphicsPacingPolicy
    public var metadataPolicy: WaylandGraphicsMetadataPolicy
    public var presentationFeedbackPolicy: WaylandGraphicsPresentationFeedbackPolicy

    public static let `default` = WaylandGraphicsConfiguration()

    public init(
        fallbackPolicy backingFallbackPolicy: WaylandGraphicsFallbackPolicy =
            .preferGPUFallbackToSoftware,
        backingPreference preferredBacking: WaylandGraphicsBackingKind = .managedGPU,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none,
        metadataPolicy frameMetadataPolicy: WaylandGraphicsMetadataPolicy = .none,
        presentationFeedbackPolicy framePresentationFeedbackPolicy:
            WaylandGraphicsPresentationFeedbackPolicy = .none,
        presentationMode requestedPresentationMode: WaylandGraphicsPresentationMode? = nil
    ) {
        presentationMode =
            requestedPresentationMode
            ?? WaylandGraphicsPresentationMode(
                backingPreference: preferredBacking,
                fallbackPolicy: backingFallbackPolicy
            )
        fallbackPolicy = backingFallbackPolicy
        synchronizationPolicy = frameSynchronizationPolicy
        pacingPolicy = framePacingPolicy
        metadataPolicy = frameMetadataPolicy
        presentationFeedbackPolicy = framePresentationFeedbackPolicy
    }

    public init(
        presentationMode requestedPresentationMode: WaylandGraphicsPresentationMode,
        fallbackPolicy backingFallbackPolicy: WaylandGraphicsFallbackPolicy =
            .preferGPUFallbackToSoftware,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none,
        metadataPolicy frameMetadataPolicy: WaylandGraphicsMetadataPolicy = .none,
        presentationFeedbackPolicy framePresentationFeedbackPolicy:
            WaylandGraphicsPresentationFeedbackPolicy = .none
    ) {
        self.init(
            fallbackPolicy: backingFallbackPolicy,
            backingPreference: requestedPresentationMode.backingPreference,
            synchronizationPolicy: frameSynchronizationPolicy,
            pacingPolicy: framePacingPolicy,
            metadataPolicy: frameMetadataPolicy,
            presentationFeedbackPolicy: framePresentationFeedbackPolicy,
            presentationMode: requestedPresentationMode
        )
    }
}

extension WaylandGraphicsConfiguration {
    package func validateManagedPreviewSupport(
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) throws {
        switch synchronizationPolicy {
        case .implicitOnly, .preferExplicit:
            break
        case .requireExplicit:
            guard capabilities.explicitSync.isAvailable else {
                throw WaylandGraphicsError.unavailable(
                    .explicitSyncRequiredButUnavailable
                )
            }
            guard presentationMode != .software,
                fallbackPolicy != .forceSoftware
            else {
                throw WaylandGraphicsError.unavailable(
                    .managedGPUSubmissionUnavailable
                )
            }
            guard capabilities.dmabuf.isAvailable else {
                throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
            }
        }

        switch pacingPolicy {
        case .none, .preferFIFO, .preferCommitTiming:
            break
        }

        switch presentationFeedbackPolicy {
        case .none, .requestWhenAvailable:
            break
        case .require:
            guard capabilities.presentationFeedback.isAvailable else {
                throw WaylandGraphicsError.unavailable(
                    .presentationFeedbackUnavailable
                )
            }
        }
    }

    package var gpuSynchronizationPolicy: GPUSynchronizationPolicy {
        switch synchronizationPolicy {
        case .implicitOnly:
            .implicitOnly
        case .preferExplicit:
            .preferExplicitFallbackToImplicit
        case .requireExplicit:
            .requireExplicit
        }
    }

    package var gpuPacingPolicy: GPUFramePacingPolicy {
        switch pacingPolicy {
        case .none:
            .none
        case .preferFIFO:
            .preferFIFO
        case .preferCommitTiming:
            .preferCommitTiming
        }
    }
}

public enum WaylandGraphicsBackingKind: Equatable, Sendable {
    case software
    case managedGPU
}

public enum WaylandGraphicsPresentationMode: Equatable, Sendable {
    case software
    case managedGPU
    case externalGPU
}

extension WaylandGraphicsPresentationMode {
    fileprivate init(
        backingPreference: WaylandGraphicsBackingKind,
        fallbackPolicy: WaylandGraphicsFallbackPolicy
    ) {
        if fallbackPolicy == .forceSoftware || backingPreference == .software {
            self = .software
        } else {
            self = .managedGPU
        }
    }

    fileprivate var backingPreference: WaylandGraphicsBackingKind {
        switch self {
        case .software:
            .software
        case .managedGPU, .externalGPU:
            .managedGPU
        }
    }
}

public enum WaylandGraphicsSynchronizationPolicy: Equatable, Sendable {
    case implicitOnly
    case preferExplicit
    case requireExplicit
}

public enum WaylandGraphicsPacingPolicy: Equatable, Sendable {
    case none
    case preferFIFO
    case preferCommitTiming
}

public enum WaylandGraphicsMetadataPolicy: Equatable, Sendable {
    case none
    case preferAvailable
}

public enum WaylandGraphicsPresentationFeedbackPolicy: Equatable, Sendable {
    case none
    case requestWhenAvailable
    case require
}

public enum WaylandGraphicsFramePacingRequest: Equatable, Sendable {
    case none
    case fifo
    case commitTiming
}

public struct WaylandGraphicsFrameSchedule: Equatable, Sendable {
    public var synchronization: WaylandGraphicsSynchronizationPolicy
    public var pacing: WaylandGraphicsFramePacingRequest
    public var presentationFeedback: WaylandGraphicsPresentationFeedbackPolicy

    public static let `default` = WaylandGraphicsFrameSchedule()

    public init(
        synchronization frameSynchronization: WaylandGraphicsSynchronizationPolicy =
            .implicitOnly,
        pacing framePacing: WaylandGraphicsFramePacingRequest = .none,
        presentationFeedback framePresentationFeedback:
            WaylandGraphicsPresentationFeedbackPolicy = .none
    ) {
        synchronization = frameSynchronization
        pacing = framePacing
        presentationFeedback = framePresentationFeedback
    }
}

public struct WaylandGraphicsSurfaceGeneration:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue generationRawValue: UInt64) {
        rawValue = generationRawValue
    }

    public var description: String {
        "surface-generation-\(rawValue)"
    }
}

public struct WaylandGraphicsExternalConfigurationID:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue configurationRawValue: UInt64) {
        rawValue = configurationRawValue
    }

    public var description: String {
        "external-configuration-\(rawValue)"
    }
}

package struct WaylandGraphicsExternalBufferID:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue bufferRawValue: UInt64) {
        rawValue = bufferRawValue
    }

    public var description: String {
        "external-buffer-\(rawValue)"
    }
}

package struct WaylandGraphicsExternalSubmissionID:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue submissionRawValue: UInt64) {
        rawValue = submissionRawValue
    }

    public var description: String {
        "external-submission-\(rawValue)"
    }
}

package struct WaylandGraphicsExternalSyncTimelineID:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue timelineRawValue: UInt64) {
        rawValue = timelineRawValue
    }

    package var description: String {
        "external-sync-timeline-\(rawValue)"
    }
}

package struct WaylandGraphicsExternalSyncTimeline:
    Equatable,
    Hashable,
    Sendable,
    Identifiable
{
    package let id: WaylandGraphicsExternalSyncTimelineID
    package let windowID: WindowID

    package init(
        id timelineID: WaylandGraphicsExternalSyncTimelineID,
        windowID backingWindowID: WindowID
    ) {
        id = timelineID
        windowID = backingWindowID
    }
}

package struct WaylandGraphicsExternalSyncPoint: Equatable, Sendable {
    package let timelineID: WaylandGraphicsExternalSyncTimelineID
    package let value: UInt64
    package let windowID: WindowID

    package init(
        timeline: WaylandGraphicsExternalSyncTimeline,
        value timelinePointValue: UInt64
    ) {
        timelineID = timeline.id
        value = timelinePointValue
        windowID = timeline.windowID
    }
}

package enum WaylandGraphicsExternalAcquireSynchronization: Equatable, Sendable {
    case drmSyncobj(WaylandGraphicsExternalSyncPoint)
}

public struct WaylandGraphicsRenderNode: Equatable, Hashable, Sendable {
    package let path: String?
    package let targetDevice: RawLinuxDmabufDevice

    package init(
        path renderNodePath: String?,
        targetDevice renderNodeTargetDevice: RawLinuxDmabufDevice
    ) {
        path = renderNodePath
        targetDevice = renderNodeTargetDevice
    }
}

public enum WaylandGraphicsExternalSynchronizationAvailability:
    Equatable,
    Sendable
{
    case implicitOnly
    case explicitAvailable
    case explicitRequiredUnavailable
}

public enum WaylandGraphicsExternalAlphaMode: Equatable, Hashable, Sendable {
    case opaque
    case premultiplied
}

public struct WaylandGraphicsExternalBufferConfiguration:
    Equatable,
    Hashable,
    Sendable
{
    public let id: WaylandGraphicsExternalConfigurationID
    public let format: WaylandGraphicsDRMFormat
    public let modifier: WaylandGraphicsDRMFormatModifier
    public let renderNode: WaylandGraphicsRenderNode
    public let alphaMode: WaylandGraphicsExternalAlphaMode
    public let scanoutPreferred: Bool
    package let generation: WaylandGraphicsSurfaceGeneration

    package init(
        id configurationID: WaylandGraphicsExternalConfigurationID,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        renderNode bufferRenderNode: WaylandGraphicsRenderNode,
        alphaMode bufferAlphaMode: WaylandGraphicsExternalAlphaMode,
        scanoutPreferred scanoutIsPreferred: Bool,
        generation surfaceGeneration: WaylandGraphicsSurfaceGeneration
    ) {
        id = configurationID
        format = bufferFormat
        modifier = bufferModifier
        renderNode = bufferRenderNode
        alphaMode = bufferAlphaMode
        scanoutPreferred = scanoutIsPreferred
        generation = surfaceGeneration
    }
}

package struct WaylandGraphicsExternalBuffer: Sendable, Identifiable {
    package let id: WaylandGraphicsExternalBufferID
    package let generation: WaylandGraphicsSurfaceGeneration
    package let configurationID: WaylandGraphicsExternalConfigurationID
    package let size: PositivePixelSize
    package let format: WaylandGraphicsDRMFormat
    package let modifier: WaylandGraphicsDRMFormatModifier
    package let renderNode: WaylandGraphicsRenderNode

    package let windowID: WindowID
    package let slotRawValue: Int
    package let storage: WaylandGraphicsWindowBackingStorage

    package init(
        id bufferID: WaylandGraphicsExternalBufferID,
        generation surfaceGeneration: WaylandGraphicsSurfaceGeneration,
        configurationID externalConfigurationID: WaylandGraphicsExternalConfigurationID,
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        renderNode bufferRenderNode: WaylandGraphicsRenderNode,
        windowID backingWindowID: WindowID,
        slotRawValue presenterSlotRawValue: Int,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        id = bufferID
        generation = surfaceGeneration
        configurationID = externalConfigurationID
        size = bufferSize
        format = bufferFormat
        modifier = bufferModifier
        renderNode = bufferRenderNode
        windowID = backingWindowID
        slotRawValue = presenterSlotRawValue
        storage = backingStorage
    }
}

public struct WaylandGraphicsFrameContract: Equatable, Sendable {
    public let generation: WaylandGraphicsSurfaceGeneration
    public let geometry: SurfaceGeometry
    public let externalBufferConfigurations: [WaylandGraphicsExternalBufferConfiguration]
    public let recommendedExternalConfigurationID: WaylandGraphicsExternalConfigurationID?
    public let synchronization: WaylandGraphicsExternalSynchronizationAvailability
    public let runtimePath: WaylandGraphicsRuntimePath
    package let windowID: WindowID

    package init(
        generation surfaceGeneration: WaylandGraphicsSurfaceGeneration,
        windowID backingWindowID: WindowID,
        geometry surfaceGeometry: SurfaceGeometry,
        externalBufferConfigurations configurations:
            [WaylandGraphicsExternalBufferConfiguration],
        recommendedExternalConfigurationID recommendedConfiguration:
            WaylandGraphicsExternalConfigurationID?,
        synchronization synchronizationAvailability:
            WaylandGraphicsExternalSynchronizationAvailability,
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath
    ) {
        generation = surfaceGeneration
        windowID = backingWindowID
        geometry = surfaceGeometry
        externalBufferConfigurations = configurations
        recommendedExternalConfigurationID = recommendedConfiguration
        synchronization = synchronizationAvailability
        runtimePath = frameRuntimePath
    }
}

public struct WaylandGraphicsDamageRegion: Equatable, Sendable {
    public let rects: [LogicalRect]

    public static let fullFrame = WaylandGraphicsDamageRegion(rects: [])

    public init(rects damageRects: [LogicalRect]) {
        rects = damageRects
    }
}

public struct WaylandGraphicsFrameMetadata: Equatable, Sendable {
    public var contentType: WaylandGraphicsContentType?
    public var presentationHint: WaylandGraphicsPresentationHint?
    public var alpha: WaylandGraphicsAlphaModifier?
    public var colorRepresentation: WaylandGraphicsColorRepresentation?
    package var colorDescription: WaylandGraphicsColorDescription?
    public var damage: WaylandGraphicsDamageRegion?

    public static let `default` = WaylandGraphicsFrameMetadata()

    public init(
        contentType frameContentType: WaylandGraphicsContentType? = nil,
        presentationHint framePresentationHint: WaylandGraphicsPresentationHint? = nil,
        alpha frameAlpha: WaylandGraphicsAlphaModifier? = nil,
        colorRepresentation frameColorRepresentation:
            WaylandGraphicsColorRepresentation? = nil,
        damage frameDamage: WaylandGraphicsDamageRegion? = nil
    ) {
        contentType = frameContentType
        presentationHint = framePresentationHint
        alpha = frameAlpha
        colorRepresentation = frameColorRepresentation
        colorDescription = nil
        damage = frameDamage
    }

    package init(
        contentType frameContentType: WaylandGraphicsContentType? = nil,
        presentationHint framePresentationHint: WaylandGraphicsPresentationHint? = nil,
        alpha frameAlpha: WaylandGraphicsAlphaModifier? = nil,
        colorRepresentation frameColorRepresentation:
            WaylandGraphicsColorRepresentation? = nil,
        colorDescription frameColorDescription: WaylandGraphicsColorDescription? = nil,
        damage frameDamage: WaylandGraphicsDamageRegion? = nil
    ) {
        contentType = frameContentType
        presentationHint = framePresentationHint
        alpha = frameAlpha
        colorRepresentation = frameColorRepresentation
        colorDescription = frameColorDescription
        damage = frameDamage
    }
}

public enum WaylandGraphicsContentType: Equatable, Sendable {
    case none
    case photo
    case video
    case game
}

public enum WaylandGraphicsPresentationHint: Equatable, Sendable {
    case vsync
    case async
}

public struct WaylandGraphicsAlphaModifier: Equatable, Sendable {
    public let rawValue: UInt32

    public static let opaque = Self(rawValue: UInt32.max)
    public static let transparent = Self(rawValue: 0)

    public init(rawValue alphaMultiplierRawValue: UInt32) {
        rawValue = alphaMultiplierRawValue
    }
}

public enum WaylandGraphicsColorAlphaMode: Equatable, Sendable {
    case premultipliedElectrical
    case premultipliedOptical
    case straight
}

public struct WaylandGraphicsColorRepresentation: Equatable, Sendable {
    public var alphaMode: WaylandGraphicsColorAlphaMode?

    public init(alphaMode colorAlphaMode: WaylandGraphicsColorAlphaMode? = nil) {
        alphaMode = colorAlphaMode
    }
}

package struct WaylandGraphicsColorDescriptionID: Equatable, Hashable, Sendable {
    package let rawValue: UInt64

    package init(rawValue colorDescriptionRawValue: UInt64) throws {
        guard colorDescriptionRawValue != 0 else {
            throw WaylandGraphicsError.unavailable(.invalidColorDescription)
        }

        rawValue = colorDescriptionRawValue
    }
}

package struct WaylandGraphicsColorDescription: Equatable, Hashable, Sendable {
    package let id: WaylandGraphicsColorDescriptionID

    package init(id colorDescriptionID: WaylandGraphicsColorDescriptionID) {
        id = colorDescriptionID
    }
}

public struct WaylandGraphicsXRGBColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public static let black = WaylandGraphicsXRGBColor(red: 0, green: 0, blue: 0)

    public init(red colorRed: UInt8, green colorGreen: UInt8, blue colorBlue: UInt8) {
        red = colorRed
        green = colorGreen
        blue = colorBlue
    }

    package var xrgb8888: UInt32 {
        (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue)
    }

    package var gpuClearColor: GPUClearColor {
        GPUClearColor(
            red: Float(red) / 255,
            green: Float(green) / 255,
            blue: Float(blue) / 255,
            alpha: 1
        )
    }
}

public struct WaylandGraphicsDRMFormat: Equatable, Hashable, Sendable {
    public let rawValue: UInt32

    public static let xrgb8888 = Self(uncheckedRawValue: 0x3432_5258)
    public static let argb8888 = Self(uncheckedRawValue: 0x3432_5241)

    public init(rawValue formatRawValue: UInt32) throws {
        guard formatRawValue != 0 else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }

        rawValue = formatRawValue
    }

    private init(uncheckedRawValue formatRawValue: UInt32) {
        rawValue = formatRawValue
    }
}

public struct WaylandGraphicsDRMFormatModifier: Equatable, Hashable, Sendable {
    public let rawValue: UInt64

    public static let linear = Self(rawValue: 0)
    public static let invalid = Self(rawValue: 0x00ff_ffff_ffff_ffff)

    public init(rawValue modifierRawValue: UInt64) {
        rawValue = modifierRawValue
    }
}

package struct WaylandGraphicsExternalBufferPlane: ~Copyable, Sendable {
    package var fileDescriptor: OwnedFileDescriptor
    package let offset: UInt32
    package let stride: UInt32
    package let planeIndex: Int

    package init(
        fileDescriptor planeFileDescriptor: consuming OwnedFileDescriptor,
        offset planeOffset: UInt32,
        stride planeStride: UInt32
    ) throws {
        try self.init(
            fd: planeFileDescriptor,
            offset: planeOffset,
            stride: planeStride,
            planeIndex: 0
        )
    }

    package init(
        fileDescriptor planeFileDescriptor: consuming OwnedFileDescriptor,
        offset planeOffset: UInt32,
        stride planeStride: UInt32,
        planeIndex planeIndexValue: UInt32
    ) throws {
        try self.init(
            fd: planeFileDescriptor,
            offset: planeOffset,
            stride: planeStride,
            planeIndex: Int(planeIndexValue)
        )
    }

    package init(
        fd planeFileDescriptor: consuming OwnedFileDescriptor,
        offset planeOffset: UInt32,
        stride planeStride: UInt32,
        planeIndex planeIndexValue: Int
    ) throws {
        guard planeIndexValue >= 0,
            planeIndexValue <= Int(UInt32.max),
            planeStride > 0
        else {
            var descriptor = planeFileDescriptor
            do {
                try descriptor.close()
            } catch {
                _ = error
            }
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }

        fileDescriptor = planeFileDescriptor
        offset = planeOffset
        stride = planeStride
        planeIndex = planeIndexValue
    }
}

package enum WaylandGraphicsExternalBufferPlanes: ~Copyable, Sendable {
    case one(WaylandGraphicsExternalBufferPlane)
    case two(WaylandGraphicsExternalBufferPlane, WaylandGraphicsExternalBufferPlane)
    case three(
        WaylandGraphicsExternalBufferPlane,
        WaylandGraphicsExternalBufferPlane,
        WaylandGraphicsExternalBufferPlane
    )
    case four(
        WaylandGraphicsExternalBufferPlane,
        WaylandGraphicsExternalBufferPlane,
        WaylandGraphicsExternalBufferPlane,
        WaylandGraphicsExternalBufferPlane
    )

    package mutating func withMutablePlanes(
        _ body: (inout WaylandGraphicsExternalBufferPlane) throws -> Void
    ) throws {
        var capturedError: (any Error)?
        switch self {
        case .one(var first):
            do {
                try body(&first)
            } catch {
                capturedError = error
            }
            self = .one(first)
        case .two(var first, var second):
            do {
                try body(&first)
                try body(&second)
            } catch {
                capturedError = error
            }
            self = .two(first, second)
        case .three(var first, var second, var third):
            do {
                try body(&first)
                try body(&second)
                try body(&third)
            } catch {
                capturedError = error
            }
            self = .three(first, second, third)
        case .four(var first, var second, var third, var fourth):
            do {
                try body(&first)
                try body(&second)
                try body(&third)
                try body(&fourth)
            } catch {
                capturedError = error
            }
            self = .four(first, second, third, fourth)
        }
        if let capturedError {
            throw capturedError
        }
    }

    package mutating func planeIndices() throws -> [Int] {
        var indices: [Int] = []
        try withMutablePlanes { plane in
            indices.append(plane.planeIndex)
        }
        return indices
    }
}

package struct WaylandGraphicsExternalBufferDescriptor: ~Copyable, Sendable {
    package let size: PositivePixelSize
    package let format: WaylandGraphicsDRMFormat
    package let modifier: WaylandGraphicsDRMFormatModifier
    private var planes: WaylandGraphicsExternalBufferPlanes

    package init(
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        plane bufferPlane: consuming WaylandGraphicsExternalBufferPlane
    ) throws {
        try self.init(
            size: bufferSize,
            format: bufferFormat,
            modifier: bufferModifier,
            planes: .one(bufferPlane)
        )
    }

    package init(
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        plane0 firstPlane: consuming WaylandGraphicsExternalBufferPlane,
        plane1 secondPlane: consuming WaylandGraphicsExternalBufferPlane
    ) throws {
        try self.init(
            size: bufferSize,
            format: bufferFormat,
            modifier: bufferModifier,
            planes: .two(firstPlane, secondPlane)
        )
    }

    package init(
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        plane0 firstPlane: consuming WaylandGraphicsExternalBufferPlane,
        plane1 secondPlane: consuming WaylandGraphicsExternalBufferPlane,
        plane2 thirdPlane: consuming WaylandGraphicsExternalBufferPlane
    ) throws {
        try self.init(
            size: bufferSize,
            format: bufferFormat,
            modifier: bufferModifier,
            planes: .three(firstPlane, secondPlane, thirdPlane)
        )
    }

    package init(
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        plane0 firstPlane: consuming WaylandGraphicsExternalBufferPlane,
        plane1 secondPlane: consuming WaylandGraphicsExternalBufferPlane,
        plane2 thirdPlane: consuming WaylandGraphicsExternalBufferPlane,
        plane3 fourthPlane: consuming WaylandGraphicsExternalBufferPlane
    ) throws {
        try self.init(
            size: bufferSize,
            format: bufferFormat,
            modifier: bufferModifier,
            planes: .four(firstPlane, secondPlane, thirdPlane, fourthPlane)
        )
    }

    package init(
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        planes bufferPlanes: consuming WaylandGraphicsExternalBufferPlanes
    ) throws {
        var planesForValidation = bufferPlanes
        try Self.validate(planes: &planesForValidation)

        size = bufferSize
        format = bufferFormat
        modifier = bufferModifier
        planes = planesForValidation
    }

    package static func validate(
        planes: inout WaylandGraphicsExternalBufferPlanes
    ) throws {
        let indices = try planes.planeIndices()
        guard indices.count == Set(indices).count else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
        guard indices.allSatisfy({ $0 >= 0 && $0 <= Int(UInt32.max) }) else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
        guard indices == Array(0..<indices.count) else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
    }
}

package struct WaylandGraphicsExternalBufferImportPlane: Sendable {
    package var fd: Int32?
    package let offset: UInt32
    package let stride: UInt32
    package let planeIndex: Int

    package init(
        fd planeFD: Int32,
        offset planeOffset: UInt32,
        stride planeStride: UInt32,
        planeIndex planeIndexValue: Int
    ) {
        fd = planeFD
        offset = planeOffset
        stride = planeStride
        planeIndex = planeIndexValue
    }

    package mutating func takeFD() throws -> Int32 {
        guard let currentFD = fd else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }

        fd = nil
        return currentFD
    }

    package mutating func closeIfNeeded() {
        guard let currentFD = fd else { return }

        fd = nil
        Glibc.close(currentFD)
    }
}

// SAFETY: the import plan owns plane descriptors during the package-internal
// handoff into the owner-thread dmabuf import path. Descriptor transfer and
// cleanup are synchronized by the storage submit path, and public API never
// exposes this mutable box.
package final class WaylandGraphicsExternalBufferImportPlan: @unchecked Sendable {
    private let size: PositivePixelSize
    private let format: WaylandGraphicsDRMFormat
    private let modifier: WaylandGraphicsDRMFormatModifier
    private var planes: [WaylandGraphicsExternalBufferImportPlane]

    package init(
        size bufferSize: PositivePixelSize,
        format bufferFormat: WaylandGraphicsDRMFormat,
        modifier bufferModifier: WaylandGraphicsDRMFormatModifier,
        planes bufferPlanes: [WaylandGraphicsExternalBufferImportPlane]
    ) {
        size = bufferSize
        format = bufferFormat
        modifier = bufferModifier
        planes = bufferPlanes
    }

    package func importBuffer(
        using linuxDmabuf: RawLinuxDmabuf,
        timeoutMilliseconds: Int32,
        syncDisplay: (Int32) throws -> Void
    ) throws -> RawLinuxDmabufBuffer {
        var runtimeFailure: RuntimeError?
        var importedBuffer: RawLinuxDmabufBuffer?
        var compositorRejectedBuffer = false

        let params = try linuxDmabuf.createBufferParams { event in
            switch event {
            case .created(let buffer):
                importedBuffer = buffer
            case .failed:
                compositorRejectedBuffer = true
            }
        } onFailure: { error in
            runtimeFailure = error
        }

        do {
            for planeIndex in planes.indices {
                let rawDescriptor = try planes[planeIndex].takeFD()
                var rawPlane = try RawLinuxDmabufPlaneFileDescriptor(
                    adopting: rawDescriptor
                )
                try params.addPlane(
                    fileDescriptor: &rawPlane,
                    planeIndex: UInt32(planes[planeIndex].planeIndex),
                    offset: planes[planeIndex].offset,
                    stride: planes[planeIndex].stride,
                    modifier: modifier.rawValue
                )
            }
            try params.create(
                width: size.width.rawValue,
                height: size.height.rawValue,
                format: format.rawValue
            )
            try syncDisplay(timeoutMilliseconds)
        } catch {
            params.destroy()
            throw error
        }

        if let runtimeFailure {
            throw runtimeFailure
        }
        if compositorRejectedBuffer {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        guard let importedBuffer else {
            throw WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }

        return importedBuffer
    }

    deinit {
        for index in planes.indices {
            planes[index].closeIfNeeded()
        }
    }
}

extension WaylandGraphicsFrameSchedule {
    package init(configuration: WaylandGraphicsConfiguration) {
        self.init(
            synchronization: configuration.synchronizationPolicy,
            pacing: WaylandGraphicsFramePacingRequest(configuration.pacingPolicy),
            presentationFeedback: configuration.presentationFeedbackPolicy
        )
    }
}

extension WaylandGraphicsFramePacingRequest {
    package init(_ policy: WaylandGraphicsPacingPolicy) {
        switch policy {
        case .none:
            self = .none
        case .preferFIFO:
            self = .fifo
        case .preferCommitTiming:
            self = .commitTiming
        }
    }

    package var policy: WaylandGraphicsPacingPolicy {
        switch self {
        case .none:
            .none
        case .fifo:
            .preferFIFO
        case .commitTiming:
            .preferCommitTiming
        }
    }
}

extension WaylandGraphicsConfiguration {
    package func applying(
        schedule: WaylandGraphicsFrameSchedule?
    ) -> WaylandGraphicsConfiguration {
        guard let schedule else { return self }

        var copy = self
        copy.synchronizationPolicy = schedule.synchronization
        copy.pacingPolicy = schedule.pacing.policy
        copy.presentationFeedbackPolicy = schedule.presentationFeedback
        return copy
    }
}

extension WaylandGraphicsExternalBufferDescriptor {
    package mutating func makeImportPlan()
        throws -> WaylandGraphicsExternalBufferImportPlan
    {
        var importPlanes: [WaylandGraphicsExternalBufferImportPlane] = []
        do {
            try planes.withMutablePlanes { plane in
                importPlanes.append(
                    WaylandGraphicsExternalBufferImportPlane(
                        fd: plane.fileDescriptor.releaseRawValue(),
                        offset: plane.offset,
                        stride: plane.stride,
                        planeIndex: plane.planeIndex
                    )
                )
            }
        } catch {
            for index in importPlanes.indices {
                importPlanes[index].closeIfNeeded()
            }
            throw error
        }

        return WaylandGraphicsExternalBufferImportPlan(
            size: size,
            format: format,
            modifier: modifier,
            planes: importPlanes
        )
    }

    package mutating func closeFileDescriptors() throws {
        try planes.withMutablePlanes { plane in
            try plane.fileDescriptor.close()
        }
    }
}

public struct WaylandGraphicsClearFrame: Equatable, Sendable {
    public let color: WaylandGraphicsXRGBColor
    public let metadata: WaylandGraphicsFrameMetadata

    public init(
        color clearColor: WaylandGraphicsXRGBColor,
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default
    ) {
        color = clearColor
        metadata = frameMetadata
    }
}

public enum WaylandGraphicsSubmittedFrame: Equatable, Sendable {
    case clearColor(WaylandGraphicsClearFrame)

    public static func clearColor(_ color: WaylandGraphicsXRGBColor) -> Self {
        .clearColor(WaylandGraphicsClearFrame(color: color))
    }

    package var metadata: WaylandGraphicsFrameMetadata {
        switch self {
        case .clearColor(let clearFrame):
            clearFrame.metadata
        }
    }
}

public enum WaylandGraphicsSubmissionOperation: Equatable, Sendable {
    case show
    case redraw
}

public struct WaylandGraphicsFrameResult: Equatable, Sendable {
    public let runtimePath: WaylandGraphicsRuntimePath
    public let operation: WaylandGraphicsSubmissionOperation
    public let size: PositivePixelSize
    public let metadata: WaylandGraphicsFrameMetadata
    public let schedule: WaylandGraphicsFrameSchedule
    public let presentationFeedbackRequested: Bool
    public let synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    public let pacingPolicy: WaylandGraphicsPacingPolicy
    public var backing: WaylandGraphicsRuntimeStatus {
        runtimePath.backing
    }

    public init(
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath,
        operation frameOperation: WaylandGraphicsSubmissionOperation,
        size frameSize: PositivePixelSize,
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        schedule frameSchedule: WaylandGraphicsFrameSchedule? = nil,
        presentationFeedbackRequested framePresentationFeedbackRequested: Bool = false,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none
    ) {
        runtimePath = frameRuntimePath
        operation = frameOperation
        size = frameSize
        metadata = frameMetadata
        schedule =
            frameSchedule
            ?? WaylandGraphicsFrameSchedule(
                synchronization: frameSynchronizationPolicy,
                pacing: WaylandGraphicsFramePacingRequest(framePacingPolicy),
                presentationFeedback: framePresentationFeedbackRequested
                    ? .requestWhenAvailable
                    : .none
            )
        presentationFeedbackRequested = framePresentationFeedbackRequested
        synchronizationPolicy = frameSynchronizationPolicy
        pacingPolicy = framePacingPolicy
    }
}

package enum WaylandGraphicsExternalReleaseResult: Equatable, Sendable {
    case released
    case backingClosed
    case failed(WaylandGraphicsUnavailableReason)
}

package actor WaylandGraphicsExternalReleaseState {
    private var result: WaylandGraphicsExternalReleaseResult?
    private var waiters: [CheckedContinuation<WaylandGraphicsExternalReleaseResult, Never>] = []

    package init() {}

    package func wait() async -> WaylandGraphicsExternalReleaseResult {
        if let result {
            return result
        }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    package func finish(_ terminalResult: WaylandGraphicsExternalReleaseResult) {
        guard result == nil else { return }

        result = terminalResult
        let continuations = waiters
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume(returning: terminalResult)
        }
    }
}

package struct WaylandGraphicsExternalBufferSubmissionReceipt: Sendable {
    package let id: WaylandGraphicsExternalSubmissionID
    package let frameResult: WaylandGraphicsFrameResult

    private let releaseState: WaylandGraphicsExternalReleaseState

    package init(
        id submissionID: WaylandGraphicsExternalSubmissionID,
        frameResult submittedFrameResult: WaylandGraphicsFrameResult,
        releaseState submissionReleaseState: WaylandGraphicsExternalReleaseState
    ) {
        id = submissionID
        frameResult = submittedFrameResult
        releaseState = submissionReleaseState
    }

    package func waitForRelease() async -> WaylandGraphicsExternalReleaseResult {
        await releaseState.wait()
    }
}

package struct WaylandGraphicsExternalBufferRenderLease: Sendable {
    package let buffer: WaylandGraphicsExternalBuffer
    package let contract: WaylandGraphicsFrameContract

    private let frameLeaseID: WaylandGraphicsFrameLeaseID
    private let storage: WaylandGraphicsWindowBackingStorage

    package init(
        buffer externalBuffer: WaylandGraphicsExternalBuffer,
        contract frameContract: WaylandGraphicsFrameContract,
        frameLeaseID leaseID: WaylandGraphicsFrameLeaseID,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        buffer = externalBuffer
        contract = frameContract
        frameLeaseID = leaseID
        storage = backingStorage
    }

    @discardableResult
    package func submit(
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        schedule frameSchedule: WaylandGraphicsFrameSchedule? = nil
    ) async throws -> WaylandGraphicsExternalBufferSubmissionReceipt {
        try await storage.submitRegisteredExternalBuffer(
            leaseID: frameLeaseID,
            buffer: buffer,
            metadata: frameMetadata,
            schedule: frameSchedule
        )
    }

    @discardableResult
    package func submit(
        acquireSynchronization: WaylandGraphicsExternalAcquireSynchronization,
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        schedule frameSchedule: WaylandGraphicsFrameSchedule? = nil
    ) async throws -> WaylandGraphicsExternalBufferSubmissionReceipt {
        try await storage.submitRegisteredExternalBuffer(
            leaseID: frameLeaseID,
            buffer: buffer,
            acquireSynchronization: acquireSynchronization,
            metadata: frameMetadata,
            schedule: frameSchedule
        )
    }

    package func cancel() async {
        await storage.cancelExternalBufferReservation(buffer)
    }
}

public enum WaylandGraphicsSubmissionStage: Equatable, Sendable {
    case windowStateCheck
    case frameGeometry
    case submissionPreparation
    case frameSubmission
    case submissionCompletion
}

public enum WaylandGraphicsSubmissionFailure: Equatable, Sendable {
    case windowLifecycle(
        windowID: WindowID,
        transition: WindowLifecycleTransitionError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case window(
        windowID: WindowID,
        error: WindowError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case display(
        error: DisplayOperationError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case client(
        error: ClientError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case unexpected(
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage,
        description: String
    )
}

public enum WaylandGraphicsError: Error, Equatable, Sendable {
    case unavailable(WaylandGraphicsUnavailableReason)
    case fallbackRequired(WaylandGraphicsFallbackReason)
    case windowClosed
    case backingClosed
    case frameLeaseActive
    case frameLeaseConsumed
    case unsupportedMetadata
    case invalidDamageRegion
    case unsupportedPacing
    case staleFrameContract
    case externalBufferUnavailable
    case foreignExternalBuffer
    case submissionFailed(WaylandGraphicsSubmissionFailure)
}

public struct WaylandGraphicsWindowBacking: Sendable {
    public let window: Window
    private let storage: WaylandGraphicsWindowBackingStorage

    init(
        window backingWindow: Window,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        window = backingWindow
        storage = backingStorage
    }

    public var runtimePath: WaylandGraphicsRuntimePath {
        get async throws {
            try await storage.runtimePath()
        }
    }

    public var id: WindowID {
        window.id
    }

    public func nextFrame() async throws -> WaylandGraphicsFrameLease {
        try await storage.nextFrame()
    }

    /// Registers a renderer-owned external buffer for repeated presentation.
    ///
    /// Registration consumes the descriptor and imports it once for this
    /// backing. The returned buffer handle is scoped to this backing and frame
    /// contract generation.
    package func registerExternalBuffer(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor,
        contract frameContract: WaylandGraphicsFrameContract,
        configurationID externalConfigurationID: WaylandGraphicsExternalConfigurationID
    ) async throws -> WaylandGraphicsExternalBuffer {
        try await storage.registerExternalBuffer(
            descriptor,
            contract: frameContract,
            configurationID: externalConfigurationID
        )
    }

    /// Imports a renderer-owned DRM syncobj timeline for explicit external submissions.
    ///
    /// The descriptor is consumed by WCK and either transferred to the compositor
    /// or closed on failure. The returned timeline is scoped to this backing.
    package func importExternalSyncTimeline(
        _ fileDescriptor: consuming OwnedFileDescriptor
    ) async throws -> WaylandGraphicsExternalSyncTimeline {
        try await storage.importExternalSyncTimeline(fileDescriptor)
    }

    /// Retires a registered external buffer that is no longer in the renderer pool.
    ///
    /// The buffer must not be reserved or awaiting compositor release. Await the
    /// submission receipt before unregistering a submitted buffer.
    package func unregisterExternalBuffer(
        _ buffer: WaylandGraphicsExternalBuffer
    ) async throws {
        try await storage.unregisterExternalBuffer(buffer)
    }

    package func nextFrameForTesting(
        afterWindowCheck: @Sendable @escaping () async -> Void
    ) async throws -> WaylandGraphicsFrameLease {
        try await storage.nextFrame(afterWindowCheck: afterWindowCheck)
    }

    public func close() async throws {
        try await storage.close()
    }
}

extension WaylandGraphicsWindowBacking: Identifiable {}

public struct WaylandGraphicsFrameLease: Sendable {
    public let size: PositivePixelSize
    public let contract: WaylandGraphicsFrameContract
    public let runtimePath: WaylandGraphicsRuntimePath

    private let storage: WaylandGraphicsWindowBackingStorage
    private let id: WaylandGraphicsFrameLeaseID

    init(
        id leaseID: WaylandGraphicsFrameLeaseID,
        size frameSize: PositivePixelSize,
        contract frameContract: WaylandGraphicsFrameContract,
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        id = leaseID
        size = frameSize
        contract = frameContract
        runtimePath = frameRuntimePath
        storage = backingStorage
    }

    @discardableResult
    public func submit(_ frame: WaylandGraphicsSubmittedFrame) async throws
        -> WaylandGraphicsFrameResult
    {
        try await storage.submit(leaseID: id, frame: frame)
    }

    @discardableResult
    public func submit(
        _ frame: WaylandGraphicsSubmittedFrame,
        schedule frameSchedule: WaylandGraphicsFrameSchedule
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submit(
            leaseID: id,
            frame: frame,
            schedule: frameSchedule
        )
    }

    @discardableResult
    public func submitSoftware(
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submitSoftware(
            leaseID: id,
            metadata: frameMetadata,
            draw
        )
    }

    @discardableResult
    public func submitSoftware(
        schedule frameSchedule: WaylandGraphicsFrameSchedule,
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submitSoftware(
            leaseID: id,
            metadata: frameMetadata,
            schedule: frameSchedule,
            draw
        )
    }

    @discardableResult
    package func submitForTestingBeforeSubmissionEffect(
        _ frame: WaylandGraphicsSubmittedFrame,
        _ beforeSubmissionEffect: @Sendable @escaping () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submit(
            leaseID: id,
            frame: frame,
            beforeSubmissionEffect: beforeSubmissionEffect,
            afterSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook
        )
    }

    @discardableResult
    package func submitForTesting(
        _ frame: WaylandGraphicsSubmittedFrame,
        afterSubmissionEffect: @Sendable @escaping () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submit(
            leaseID: id,
            frame: frame,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: afterSubmissionEffect
        )
    }

    public func cancel() async {
        await storage.cancel(leaseID: id)
    }

    package func reserveExternalBuffer(
        _ buffer: WaylandGraphicsExternalBuffer
    ) async throws -> WaylandGraphicsExternalBufferRenderLease {
        try await storage.reserveExternalBuffer(
            buffer,
            leaseID: id,
            contract: contract
        )
    }
}

extension WaylandGraphicsSubmittedFrame {
    package func validateManagedPreviewSupport(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws {
        switch self {
        case .clearColor(let clearFrame):
            try clearFrame.metadata.validateManagedPreviewSupport(
                configuration: configuration,
                capabilities: capabilities,
                geometry: geometry
            )
        }
    }
}

extension WaylandGraphicsFrameMetadata {
    package func validateManagedPreviewSupport(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws {
        _ = capabilities
        try damage?.validateManagedPreviewSupport(geometry: geometry)
        if hasCommitMetadata, configuration.metadataPolicy == .none {
            throw WaylandGraphicsError.unsupportedMetadata
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    package func resolveManagedPreviewMetadata(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws -> WaylandGraphicsResolvedFrameMetadata {
        try validateManagedPreviewSupport(
            configuration: configuration,
            capabilities: capabilities,
            geometry: geometry
        )

        var commitMetadata = SurfaceCommitMetadata.default
        var fallbacks = WaylandGraphicsMetadataFallbacks.none
        if let contentType {
            if capabilities.colorMetadata.contentType.isAvailable {
                commitMetadata.contentType = contentType.surfaceContentType
            } else {
                fallbacks.contentType = true
            }
        }
        if let presentationHint {
            if capabilities.colorMetadata.tearingControl.isAvailable {
                commitMetadata.presentationHint = presentationHint.surfacePresentationHint
            } else {
                fallbacks.presentationHint = true
            }
        }
        if let alpha {
            if capabilities.colorMetadata.alphaModifier.isAvailable {
                commitMetadata.alpha = alpha.surfaceAlphaMetadata
            } else {
                fallbacks.alpha = true
            }
        }
        if let colorRepresentation {
            switch capabilities.colorMetadata.colorRepresentation {
            case .available:
                commitMetadata.colorRepresentation =
                    colorRepresentation.surfaceColorRepresentation
            case .pending:
                fallbacks.colorRepresentationPending = true
            case .unavailable:
                fallbacks.colorRepresentation = true
            }
        }
        if let colorDescription {
            if capabilities.colorMetadata.colorManagement.isAvailable {
                commitMetadata.colorDescription =
                    try colorDescription.surfaceColorDescriptionReference
            } else {
                fallbacks.colorDescription = true
            }
        }

        return WaylandGraphicsResolvedFrameMetadata(
            commitMetadata: commitMetadata,
            fallbacks: fallbacks
        )
    }

    package func surfaceCommitMetadata() throws -> SurfaceCommitMetadata {
        SurfaceCommitMetadata(
            contentType: contentType?.surfaceContentType,
            alpha: alpha?.surfaceAlphaMetadata,
            colorRepresentation: colorRepresentation?.surfaceColorRepresentation,
            colorDescription: try colorDescription?.surfaceColorDescriptionReference,
            presentationHint: presentationHint?.surfacePresentationHint
        )
    }

    package func surfaceDamageRegion() throws -> SurfaceDamageRegion? {
        try damage?.surfaceDamageRegion()
    }

    private var hasCommitMetadata: Bool {
        contentType != nil
            || presentationHint != nil
            || alpha != nil
            || colorRepresentation != nil
            || colorDescription != nil
    }
}

extension WaylandGraphicsDamageRegion {
    package func validateManagedPreviewSupport(geometry: SurfaceGeometry) throws {
        let region = try surfaceDamageRegion()
        do {
            try region?.validate(within: geometry)
        } catch {
            throw WaylandGraphicsError.invalidDamageRegion
        }
    }

    package func surfaceDamageRegion() throws -> SurfaceDamageRegion? {
        guard !rects.isEmpty else { return nil }

        do {
            return try SurfaceDamageRegion(rects)
        } catch {
            throw WaylandGraphicsError.invalidDamageRegion
        }
    }
}

extension WaylandGraphicsContentType {
    package var surfaceContentType: SurfaceContentType {
        switch self {
        case .none:
            .none
        case .photo:
            .photo
        case .video:
            .video
        case .game:
            .game
        }
    }
}

extension WaylandGraphicsPresentationHint {
    package var surfacePresentationHint: SurfacePresentationHint {
        switch self {
        case .vsync:
            .vsync
        case .async:
            .async
        }
    }
}

extension WaylandGraphicsAlphaModifier {
    package var surfaceAlphaMetadata: SurfaceAlphaMetadata {
        SurfaceAlphaMetadata(
            multiplier: SurfaceAlphaMultiplier(rawValue: rawValue)
        )
    }
}

extension WaylandGraphicsColorAlphaMode {
    package var surfaceAlphaMode: SurfaceAlphaMode {
        switch self {
        case .premultipliedElectrical:
            .premultipliedElectrical
        case .premultipliedOptical:
            .premultipliedOptical
        case .straight:
            .straight
        }
    }
}

extension WaylandGraphicsColorRepresentation {
    package var surfaceColorRepresentation: SurfaceColorRepresentation {
        SurfaceColorRepresentation(alphaMode: alphaMode?.surfaceAlphaMode)
    }
}

extension WaylandGraphicsColorDescription {
    package var surfaceColorDescriptionReference: SurfaceColorDescriptionReference {
        get throws {
            try SurfaceColorDescriptionReference(identity: id.rawValue)
        }
    }
}

func noGraphicsPreviewSubmissionHook() async {
    _ = ()
}

func noThrowingGraphicsPreviewSubmissionHook() async throws {
    _ = ()
}
