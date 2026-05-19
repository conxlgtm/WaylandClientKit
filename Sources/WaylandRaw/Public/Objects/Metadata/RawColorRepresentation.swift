import CWaylandProtocols

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
