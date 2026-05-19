import CWaylandProtocols

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
