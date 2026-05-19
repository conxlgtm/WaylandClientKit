// swiftlint:disable file_length
import CWaylandProtocols

private func ignoreSurfaceMetadataProxyDestroy() {
    // Optional destruction hook for tests.
}

package enum RawSurfaceMetadataError: Error, Equatable, Sendable, CustomStringConvertible {
    case contentTypeAlreadyExists
    case alphaModifierAlreadyExists
    case tearingControlAlreadyExists
    case colorRepresentationAlreadyExists
    case colorManagementSurfaceAlreadyExists
    case surfaceFeedbackAlreadyExists
    case colorManagementOutputAlreadyExists
    case invalidImageDescriptionIdentity

    package var description: String {
        switch self {
        case .contentTypeAlreadyExists:
            "surface already has a content type object"
        case .alphaModifierAlreadyExists:
            "surface already has an alpha modifier object"
        case .tearingControlAlreadyExists:
            "surface already has a tearing control object"
        case .colorRepresentationAlreadyExists:
            "surface already has a color representation object"
        case .colorManagementSurfaceAlreadyExists:
            "surface already has a color management object"
        case .surfaceFeedbackAlreadyExists:
            "surface already has a color management feedback object"
        case .colorManagementOutputAlreadyExists:
            "output already has a color management object"
        case .invalidImageDescriptionIdentity:
            "image description identity must be nonzero"
        }
    }
}

package struct RawContentType: Equatable, Sendable {
    package let rawValue: UInt32

    package static let none = Self(rawValue: 0)
    package static let photo = Self(rawValue: 1)
    package static let video = Self(rawValue: 2)
    package static let game = Self(rawValue: 3)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawAlphaMultiplier: Equatable, Sendable {
    package let rawValue: UInt32

    package static let opaque = Self(rawValue: UInt32.max)
    package static let transparent = Self(rawValue: 0)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package enum RawPresentationHint: Equatable, Sendable {
    case vsync
    case async
    case unknown(UInt32)

    package var rawValue: UInt32 {
        switch self {
        case .vsync:
            0
        case .async:
            1
        case .unknown(let value):
            value
        }
    }
}

package struct RawSurfaceAlphaMode: Equatable, Sendable {
    package let rawValue: UInt32

    package static let premultipliedElectrical = Self(rawValue: 0)
    package static let premultipliedOptical = Self(rawValue: 1)
    package static let straight = Self(rawValue: 2)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawSurfaceMatrixCoefficients: Equatable, Sendable {
    package let rawValue: UInt32

    package static let identity = Self(rawValue: 1)
    package static let bt709 = Self(rawValue: 2)
    package static let fcc = Self(rawValue: 3)
    package static let bt601 = Self(rawValue: 4)
    package static let smpte240 = Self(rawValue: 5)
    package static let bt2020 = Self(rawValue: 6)
    package static let bt2020ConstantLuminance = Self(rawValue: 7)
    package static let ictcp = Self(rawValue: 8)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawSurfaceQuantizationRange: Equatable, Sendable {
    package let rawValue: UInt32

    package static let full = Self(rawValue: 1)
    package static let limited = Self(rawValue: 2)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawSurfaceChromaLocation: Equatable, Sendable {
    package let rawValue: UInt32

    package static let type0 = Self(rawValue: 1)
    package static let type1 = Self(rawValue: 2)
    package static let type2 = Self(rawValue: 3)
    package static let type3 = Self(rawValue: 4)
    package static let type4 = Self(rawValue: 5)
    package static let type5 = Self(rawValue: 6)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawSurfaceCoefficientsAndRange: Equatable, Sendable {
    package let coefficients: RawSurfaceMatrixCoefficients
    package let range: RawSurfaceQuantizationRange

    package init(
        coefficients matrixCoefficients: RawSurfaceMatrixCoefficients,
        range quantizationRange: RawSurfaceQuantizationRange
    ) {
        coefficients = matrixCoefficients
        range = quantizationRange
    }
}

package struct RawColorRenderIntent: Equatable, Sendable {
    package let rawValue: UInt32

    package static let perceptual = Self(rawValue: 0)
    package static let relative = Self(rawValue: 1)
    package static let saturation = Self(rawValue: 2)
    package static let absolute = Self(rawValue: 3)
    package static let relativeBlackPointCompensation = Self(rawValue: 4)
    package static let absoluteNoAdaptation = Self(rawValue: 5)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawImageDescriptionFailureCause: Equatable, Sendable {
    package let rawValue: UInt32

    package static let lowVersion = Self(rawValue: 0)
    package static let unsupported = Self(rawValue: 1)
    package static let operatingSystem = Self(rawValue: 2)
    package static let noOutput = Self(rawValue: 3)
    package static let invalidIdentity = Self(rawValue: UInt32.max)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package enum RawImageDescriptionState: Equatable, Sendable {
    case pending
    case ready(identity: RawImageDescriptionIdentity)
    case failed(cause: RawImageDescriptionFailureCause, message: String)
}

package struct RawImageDescriptionIdentity: Equatable, Hashable, Sendable {
    package let rawValue: UInt64

    package init(_ identity: UInt64) throws(RawSurfaceMetadataError) {
        guard identity != 0 else {
            throw .invalidImageDescriptionIdentity
        }

        rawValue = identity
    }
}

@safe
package final class RawContentTypeManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_content_type_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_content_type_manager_v1_destroy
        )
    }

    package func contentType(for surface: RawSurface) throws(RuntimeError)
        -> RawContentTypeSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.contentTypeAlreadyExists.description
            )
        }

        guard
            let contentType = unsafe swl_wp_content_type_manager_v1_get_surface_content_type(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_content_type_v1")
        }

        let adoptedContentType = try unsafe proxyAdoption.adoptOrDestroy(
            contentType,
            interface: "wp_content_type_v1",
            destroy: unsafe swl_wp_content_type_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawContentTypeSurface(
            pointer: adoptedContentType,
            destroy: unsafe swl_wp_content_type_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func destroy() {
        surfaceIDs.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawContentTypeSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer contentTypePointer: OpaquePointer,
        destroy destroyContentType: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: contentTypePointer, destroy: destroyContentType)
        onDestroy = handleDestroy
    }

    package func setContentType(_ contentType: RawContentType) {
        unsafe swl_wp_content_type_v1_set_content_type(pointer, contentType.rawValue)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawAlphaModifierManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_alpha_modifier_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_alpha_modifier_v1_destroy
        )
    }

    package func alphaModifier(for surface: RawSurface) throws(RuntimeError)
        -> RawAlphaModifierSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.alphaModifierAlreadyExists.description
            )
        }

        guard
            let alphaModifier = unsafe swl_wp_alpha_modifier_v1_get_surface(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_alpha_modifier_surface_v1")
        }

        let adoptedSurface = try unsafe proxyAdoption.adoptOrDestroy(
            alphaModifier,
            interface: "wp_alpha_modifier_surface_v1",
            destroy: unsafe swl_wp_alpha_modifier_surface_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawAlphaModifierSurface(
            pointer: adoptedSurface,
            destroy: unsafe swl_wp_alpha_modifier_surface_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func destroy() {
        surfaceIDs.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawAlphaModifierSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer surfacePointer: OpaquePointer,
        destroy destroySurface: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: surfacePointer, destroy: destroySurface)
        onDestroy = handleDestroy
    }

    package func setMultiplier(_ multiplier: RawAlphaMultiplier) {
        unsafe swl_wp_alpha_modifier_surface_v1_set_multiplier(
            pointer,
            multiplier.rawValue
        )
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTearingControlManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_tearing_control_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_tearing_control_manager_v1_destroy
        )
    }

    package func tearingControl(for surface: RawSurface) throws(RuntimeError)
        -> RawTearingControl
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.tearingControlAlreadyExists.description
            )
        }

        guard
            let tearingControl =
                unsafe swl_wp_tearing_control_manager_v1_get_tearing_control(
                    pointer,
                    surface.pointer
                )
        else {
            throw RuntimeError.bindFailed("wp_tearing_control_v1")
        }

        let adoptedTearingControl = try unsafe proxyAdoption.adoptOrDestroy(
            tearingControl,
            interface: "wp_tearing_control_v1",
            destroy: unsafe swl_wp_tearing_control_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawTearingControl(
            pointer: adoptedTearingControl,
            destroy: unsafe swl_wp_tearing_control_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func destroy() {
        surfaceIDs.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTearingControl {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer tearingControlPointer: OpaquePointer,
        destroy destroyTearingControl: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(
            pointer: tearingControlPointer,
            destroy: destroyTearingControl
        )
        onDestroy = handleDestroy
    }

    package func setPresentationHint(_ hint: RawPresentationHint) {
        unsafe swl_wp_tearing_control_v1_set_presentation_hint(pointer, hint.rawValue)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawColorRepresentationManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private let owner: ColorRepresentationManagerOwner
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    package var supportedAlphaModes: [RawSurfaceAlphaMode] {
        owner.supportedAlphaModes
    }

    package var supportedCoefficientsAndRanges: [RawSurfaceCoefficientsAndRange] {
        owner.supportedCoefficientsAndRanges
    }

    package var hasReceivedSupportDone: Bool {
        owner.hasReceivedDone
    }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        let newOwner = ColorRepresentationManagerOwner(
            manager: managerPointer,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )

        version = managerVersion
        proxyAdoption = adoptionContext
        owner = newOwner
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_color_representation_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_color_representation_manager_v1_destroy
        )
        try newOwner.install()
    }

    package func colorRepresentation(for surface: RawSurface)
        throws(RuntimeError) -> RawColorRepresentationSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.colorRepresentationAlreadyExists.description
            )
        }

        guard
            let representation =
                unsafe swl_wp_color_representation_manager_v1_get_surface(
                    pointer,
                    surface.pointer
                )
        else {
            throw RuntimeError.bindFailed("wp_color_representation_surface_v1")
        }

        let adoptedRepresentation = try unsafe proxyAdoption.adoptOrDestroy(
            representation,
            interface: "wp_color_representation_surface_v1",
            destroy: unsafe swl_wp_color_representation_surface_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawColorRepresentationSurface(
            pointer: adoptedRepresentation,
            destroy: unsafe swl_wp_color_representation_surface_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func destroy() {
        owner.cancel()
        surfaceIDs.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class ColorRepresentationManagerOwner {
    @safe private let manager: OpaquePointer
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    private(set) var supportedAlphaModes: [RawSurfaceAlphaMode] = []
    private(set) var supportedCoefficientsAndRanges: [RawSurfaceCoefficientsAndRange] = []
    private(set) var hasReceivedDone = false

    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue:
            unsafe swl_wp_color_representation_manager_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_wp_color_representation_manager_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    @safe
    init(
        manager managerPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        unsafe manager = managerPointer
        invariantFailureSink = failureSink
        let cb = callbacks

        unsafe cb.pointee.supported_alpha_mode = { data, _, alphaMode in
            ColorRepresentationManagerOwner.withOwner(
                data,
                message: "color representation manager alpha mode fired without Swift state"
            ) { owner in
                owner.supportedAlphaModes.append(
                    RawSurfaceAlphaMode(rawValue: alphaMode)
                )
            }
        }

        unsafe cb.pointee.supported_coefficients_and_ranges = { data, _, coefficients, range in
            ColorRepresentationManagerOwner.withOwner(
                data,
                message:
                    "color representation manager coefficients fired without Swift state"
            ) { owner in
                owner.supportedCoefficientsAndRanges.append(
                    RawSurfaceCoefficientsAndRange(
                        coefficients:
                            RawSurfaceMatrixCoefficients(rawValue: coefficients),
                        range: RawSurfaceQuantizationRange(rawValue: range)
                    )
                )
            }
        }

        unsafe cb.pointee.done = { data, _ in
            ColorRepresentationManagerOwner.withOwner(
                data,
                message: "color representation manager done fired without Swift state"
            ) { owner in
                owner.hasReceivedDone = true
            }
        }
    }

    func install() throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "wp_color_representation_manager_v1") {
            unsafe swl_wp_color_representation_manager_v1_add_listener(
                manager,
                callbacks
            )
        }
    }

    func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (ColorRepresentationManagerOwner) -> Void
    ) {
        CListenerStorage<
            ColorRepresentationManagerOwner,
            swl_wp_color_representation_manager_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawColorRepresentationSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer surfacePointer: OpaquePointer,
        destroy destroySurface: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: surfacePointer, destroy: destroySurface)
        onDestroy = handleDestroy
    }

    package func setAlphaMode(_ alphaMode: RawSurfaceAlphaMode) {
        unsafe swl_wp_color_representation_surface_v1_set_alpha_mode(
            pointer,
            alphaMode.rawValue
        )
    }

    package func setCoefficientsAndRange(
        _ coefficientsAndRange:
            RawSurfaceCoefficientsAndRange
    ) {
        unsafe swl_wp_color_representation_surface_v1_set_coefficients_and_range(
            pointer,
            coefficientsAndRange.coefficients.rawValue,
            coefficientsAndRange.range.rawValue
        )
    }

    package func setChromaLocation(_ chromaLocation: RawSurfaceChromaLocation) {
        unsafe swl_wp_color_representation_surface_v1_set_chroma_location(
            pointer,
            chromaLocation.rawValue
        )
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawColorManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private let owner: ColorManagerOwner
    private var proxy: RawOwnedProxy
    private var outputIDs: Set<RawOutputID> = []
    private var surfaceIDs: Set<RawObjectID> = []
    private var surfaceFeedbackIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    package var supportedRenderIntents: [RawColorRenderIntent] {
        owner.supportedRenderIntents
    }

    package var supportedFeatures: [UInt32] {
        owner.supportedFeatures
    }

    package var supportedNamedTransferFunctions: [UInt32] {
        owner.supportedNamedTransferFunctions
    }

    package var supportedNamedPrimaries: [UInt32] {
        owner.supportedNamedPrimaries
    }

    package var hasReceivedSupportDone: Bool {
        owner.hasReceivedDone
    }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        let newOwner = ColorManagerOwner(
            manager: managerPointer,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )

        version = managerVersion
        proxyAdoption = adoptionContext
        owner = newOwner
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_color_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_color_manager_v1_destroy
        )
        try newOwner.install()
    }

    package func output(for output: RawOutput) throws(RuntimeError)
        -> RawColorManagementOutput
    {
        let outputID = output.id
        guard !outputIDs.contains(outputID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.colorManagementOutputAlreadyExists.description
            )
        }

        guard
            let colorOutput = unsafe swl_wp_color_manager_v1_get_output(
                pointer,
                output.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_color_management_output_v1")
        }

        let adoptedOutput = try unsafe proxyAdoption.adoptOrDestroy(
            colorOutput,
            interface: "wp_color_management_output_v1",
            destroy: unsafe swl_wp_color_management_output_v1_destroy
        )
        outputIDs.insert(outputID)
        return RawColorManagementOutput(
            pointer: adoptedOutput,
            proxyAdoption: proxyAdoption,
            destroy: unsafe swl_wp_color_management_output_v1_destroy
        ) { [weak self] in
            self?.outputIDs.remove(outputID)
        }
    }

    package func surface(for surface: RawSurface) throws(RuntimeError)
        -> RawColorManagementSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.colorManagementSurfaceAlreadyExists.description
            )
        }

        guard
            let colorSurface = unsafe swl_wp_color_manager_v1_get_surface(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_color_management_surface_v1")
        }

        let adoptedSurface = try unsafe proxyAdoption.adoptOrDestroy(
            colorSurface,
            interface: "wp_color_management_surface_v1",
            destroy: unsafe swl_wp_color_management_surface_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawColorManagementSurface(
            pointer: adoptedSurface,
            destroy: unsafe swl_wp_color_management_surface_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func surfaceFeedback(for surface: RawSurface) throws(RuntimeError)
        -> RawColorManagementSurfaceFeedback
    {
        let surfaceID = surface.objectID
        guard !surfaceFeedbackIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.surfaceFeedbackAlreadyExists
                    .description
            )
        }

        guard
            let feedback = unsafe swl_wp_color_manager_v1_get_surface_feedback(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_color_management_surface_feedback_v1")
        }

        let adoptedFeedback = try unsafe proxyAdoption.adoptOrDestroy(
            feedback,
            interface: "wp_color_management_surface_feedback_v1",
            destroy: unsafe swl_wp_color_management_surface_feedback_v1_destroy
        )
        surfaceFeedbackIDs.insert(surfaceID)
        return RawColorManagementSurfaceFeedback(
            pointer: adoptedFeedback,
            proxyAdoption: proxyAdoption,
            destroy: unsafe swl_wp_color_management_surface_feedback_v1_destroy
        ) { [weak self] in
            self?.surfaceFeedbackIDs.remove(surfaceID)
        }
    }

    package func imageDescription(for reference: RawImageDescriptionReference)
        throws(RuntimeError) -> RawImageDescription
    {
        guard version >= 2 else {
            throw RuntimeError.unsupportedProtocolVersion(
                interface: "wp_color_manager_v1.get_image_description",
                minimum: 2,
                actual: version
            )
        }

        guard
            let imageDescription = unsafe swl_wp_color_manager_v1_get_image_description(
                pointer,
                reference.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_image_description_v1")
        }

        let adoptedDescription = try unsafe proxyAdoption.adoptOrDestroy(
            imageDescription,
            interface: "wp_image_description_v1",
            destroy: unsafe swl_wp_image_description_v1_destroy
        )
        return try RawImageDescription(
            pointer: adoptedDescription,
            proxyAdoption: proxyAdoption,
            destroy: unsafe swl_wp_image_description_v1_destroy
        )
    }

    package func destroy() {
        owner.cancel()
        outputIDs.removeAll(keepingCapacity: false)
        surfaceIDs.removeAll(keepingCapacity: false)
        surfaceFeedbackIDs.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class ColorManagerOwner {
    @safe private let manager: OpaquePointer
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    private(set) var supportedRenderIntents: [RawColorRenderIntent] = []
    private(set) var supportedFeatures: [UInt32] = []
    private(set) var supportedNamedTransferFunctions: [UInt32] = []
    private(set) var supportedNamedPrimaries: [UInt32] = []
    private(set) var hasReceivedDone = false

    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_wp_color_manager_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_wp_color_manager_v1_listener_callbacks> {
        listenerStorage.callbacks
    }

    @safe
    init(
        manager managerPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        unsafe manager = managerPointer
        invariantFailureSink = failureSink
        let cb = callbacks

        unsafe cb.pointee.supported_intent = { data, _, renderIntent in
            ColorManagerOwner.withOwner(
                data,
                message: "color manager supported intent fired without Swift state"
            ) { owner in
                owner.supportedRenderIntents.append(
                    RawColorRenderIntent(rawValue: renderIntent)
                )
            }
        }

        unsafe cb.pointee.supported_feature = { data, _, feature in
            ColorManagerOwner.withOwner(
                data,
                message: "color manager supported feature fired without Swift state"
            ) { owner in
                owner.supportedFeatures.append(feature)
            }
        }

        unsafe cb.pointee.supported_tf_named = { data, _, transferFunction in
            ColorManagerOwner.withOwner(
                data,
                message:
                    "color manager supported transfer function fired without Swift state"
            ) { owner in
                owner.supportedNamedTransferFunctions.append(transferFunction)
            }
        }

        unsafe cb.pointee.supported_primaries_named = { data, _, primaries in
            ColorManagerOwner.withOwner(
                data,
                message: "color manager supported primaries fired without Swift state"
            ) { owner in
                owner.supportedNamedPrimaries.append(primaries)
            }
        }

        unsafe cb.pointee.done = { data, _ in
            ColorManagerOwner.withOwner(
                data,
                message: "color manager done fired without Swift state"
            ) { owner in
                owner.hasReceivedDone = true
            }
        }
    }

    func install() throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "wp_color_manager_v1") {
            unsafe swl_wp_color_manager_v1_add_listener(manager, callbacks)
        }
    }

    func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (ColorManagerOwner) -> Void
    ) {
        CListenerStorage<ColorManagerOwner, swl_wp_color_manager_v1_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawColorManagementOutput {
    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer outputPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        destroy destroyOutput: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxyAdoption = adoptionContext
        proxy = RawOwnedProxy(pointer: outputPointer, destroy: destroyOutput)
        onDestroy = handleDestroy
    }

    package func imageDescription() throws(RuntimeError) -> RawImageDescription {
        guard
            let imageDescription =
                unsafe swl_wp_color_management_output_v1_get_image_description(
                    pointer
                )
        else {
            throw RuntimeError.bindFailed("wp_image_description_v1")
        }

        let adoptedDescription = try unsafe proxyAdoption.adoptOrDestroy(
            imageDescription,
            interface: "wp_image_description_v1",
            destroy: unsafe swl_wp_image_description_v1_destroy
        )
        return try RawImageDescription(
            pointer: adoptedDescription,
            proxyAdoption: proxyAdoption,
            destroy: unsafe swl_wp_image_description_v1_destroy
        )
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawColorManagementSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer surfacePointer: OpaquePointer,
        destroy destroySurface: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: surfacePointer, destroy: destroySurface)
        onDestroy = handleDestroy
    }

    package func setImageDescription(
        _ imageDescription: RawImageDescription,
        renderIntent: RawColorRenderIntent
    ) {
        unsafe swl_wp_color_management_surface_v1_set_image_description(
            pointer,
            imageDescription.pointer,
            renderIntent.rawValue
        )
    }

    package func unsetImageDescription() {
        unsafe swl_wp_color_management_surface_v1_unset_image_description(pointer)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawColorManagementSurfaceFeedback {
    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer feedbackPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        destroy destroyFeedback: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxyAdoption = adoptionContext
        proxy = RawOwnedProxy(pointer: feedbackPointer, destroy: destroyFeedback)
        onDestroy = handleDestroy
    }

    package func preferredImageDescription() throws(RuntimeError)
        -> RawImageDescription
    {
        guard
            let imageDescription =
                unsafe swl_wp_color_management_surface_feedback_v1_get_preferred(
                    pointer
                )
        else {
            throw RuntimeError.bindFailed("wp_image_description_v1")
        }

        let adoptedDescription = try unsafe proxyAdoption.adoptOrDestroy(
            imageDescription,
            interface: "wp_image_description_v1",
            destroy: unsafe swl_wp_image_description_v1_destroy
        )
        return try RawImageDescription(
            pointer: adoptedDescription,
            proxyAdoption: proxyAdoption,
            destroy: unsafe swl_wp_image_description_v1_destroy
        )
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawImageDescription {
    private var proxy: RawOwnedProxy
    private let owner: ImageDescriptionOwner?
    private let testingState: RawImageDescriptionState?
    private var isDestroyed = false

    @safe package var pointer: OpaquePointer { proxy.pointer }

    package var state: RawImageDescriptionState {
        owner?.state ?? testingState ?? .pending
    }

    @safe
    package init(
        pointer imageDescriptionPointer: OpaquePointer,
        destroy destroyImageDescription: @escaping (OpaquePointer) -> Void,
        state initialState: RawImageDescriptionState = .pending
    ) {
        owner = nil
        testingState = initialState
        proxy = RawOwnedProxy(
            pointer: imageDescriptionPointer,
            destroy: destroyImageDescription
        )
    }

    @safe
    package init(
        pointer imageDescriptionPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        destroy destroyImageDescription: @escaping (OpaquePointer) -> Void
    ) throws(RuntimeError) {
        let newOwner = ImageDescriptionOwner(
            imageDescription: imageDescriptionPointer,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )

        owner = newOwner
        testingState = nil
        proxy = RawOwnedProxy(
            pointer: imageDescriptionPointer,
            destroy: destroyImageDescription
        )
        do {
            try newOwner.install()
        } catch {
            proxy.destroy()
            isDestroyed = true
            throw error
        }
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        owner?.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class ImageDescriptionOwner {
    @safe private let imageDescription: OpaquePointer
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    private(set) var state = RawImageDescriptionState.pending

    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_wp_image_description_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_wp_image_description_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    @safe
    init(
        imageDescription imageDescriptionPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        unsafe imageDescription = imageDescriptionPointer
        invariantFailureSink = failureSink
        let cb = callbacks

        unsafe cb.pointee.failed = { data, _, cause, message in
            ImageDescriptionOwner.withOwner(
                data,
                message: "image description failed fired without Swift state"
            ) { owner in
                let failureMessage =
                    unsafe message.map { pointer in
                        unsafe String(cString: pointer)
                    } ?? ""
                owner.state = .failed(
                    cause: RawImageDescriptionFailureCause(rawValue: cause),
                    message: failureMessage
                )
            }
        }

        unsafe cb.pointee.ready = { data, _, identity in
            ImageDescriptionOwner.withOwner(
                data,
                message: "image description ready fired without Swift state"
            ) { owner in
                owner.state = ImageDescriptionOwner.readyState(
                    identity: UInt64(identity)
                )
            }
        }

        unsafe cb.pointee.ready2 = { data, _, identityHigh, identityLow in
            ImageDescriptionOwner.withOwner(
                data,
                message: "image description ready2 fired without Swift state"
            ) { owner in
                owner.state = ImageDescriptionOwner.readyState(
                    identity: UInt64(identityHigh) << 32 | UInt64(identityLow)
                )
            }
        }
    }

    private static func readyState(identity: UInt64) -> RawImageDescriptionState {
        do {
            return .ready(identity: try RawImageDescriptionIdentity(identity))
        } catch {
            return .failed(
                cause: .invalidIdentity,
                message: "image description identity must be nonzero"
            )
        }
    }

    func install() throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "wp_image_description_v1") {
            unsafe swl_wp_image_description_v1_add_listener(
                imageDescription,
                callbacks
            )
        }
    }

    func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (ImageDescriptionOwner) -> Void
    ) {
        CListenerStorage<
            ImageDescriptionOwner,
            swl_wp_image_description_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawImageDescriptionReference {
    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer referencePointer: OpaquePointer,
        destroy destroyReference: @escaping (OpaquePointer) -> Void
    ) {
        proxy = RawOwnedProxy(pointer: referencePointer, destroy: destroyReference)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
