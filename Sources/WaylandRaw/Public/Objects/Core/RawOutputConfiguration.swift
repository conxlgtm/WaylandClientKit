import CWaylandProtocols

@safe
private final class RawWlrOutputConfigurationListenerOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawWlrOutputConfigurationEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwlr_output_configuration_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwlr_output_configuration_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent eventHandler: @escaping (RawWlrOutputConfigurationEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = eventHandler

        unsafe callbacks.pointee.succeeded = { data, _ in
            RawWlrOutputConfigurationListenerOwner.withOwner(
                data,
                message:
                    "zwlr_output_configuration_v1 succeeded fired without Swift state"
            ) { owner in
                owner.append(.succeeded)
            }
        }
        unsafe callbacks.pointee.failed = { data, _ in
            RawWlrOutputConfigurationListenerOwner.withOwner(
                data,
                message:
                    "zwlr_output_configuration_v1 failed fired without Swift state"
            ) { owner in
                owner.append(.failed)
            }
        }
        unsafe callbacks.pointee.cancelled = { data, _ in
            RawWlrOutputConfigurationListenerOwner.withOwner(
                data,
                message:
                    "zwlr_output_configuration_v1 cancelled fired without Swift state"
            ) { owner in
                owner.append(.cancelled)
            }
        }
    }

    func install(on configuration: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwlr_output_configuration_v1_add_listener(
            configuration,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwlr_output_configuration_v1")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawWlrOutputConfigurationEvent) {
        guard !isCanceled else { return }
        onEvent(event)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawWlrOutputConfigurationListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawWlrOutputConfigurationListenerOwner,
            swl_zwlr_output_configuration_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

extension RawWlrOutputManager {
    @safe
    package static func testingOutputManager(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) -> RawWlrOutputManager {
        RawWlrOutputManager(
            testingPointer: managerPointer,
            version: managerVersion,
            proxyAdoption: adoptionContext
        )
    }
}

@safe
package final class RawWlrOutputHead {
    private var proxy: RawOwnedProxy
    private var modes: [RawWlrOutputMode] = []
    private let listenerOwner: RawWlrOutputHeadListenerOwner?

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(pointer headPointer: OpaquePointer, version: RawVersion = RawVersion(4)) {
        listenerOwner = nil
        proxy = RawOwnedProxy(
            pointer: headPointer,
            destroy: version >= RawVersion(3)
                ? unsafe swl_zwlr_output_head_v1_release
                : unsafe swl_zwlr_output_head_v1_destroy
        )
    }

    @safe
    init(
        pointer headPointer: OpaquePointer,
        version headVersion: RawVersion,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent: @escaping (RawWlrOutputHeadEvent) -> Void
    ) throws(RuntimeError) {
        listenerOwner = RawWlrOutputHeadListenerOwner(
            version: headVersion,
            invariantFailureSink: failureSink,
            onEvent: onEvent
        )
        proxy = RawOwnedProxy(
            pointer: headPointer,
            destroy: headVersion >= RawVersion(3)
                ? unsafe swl_zwlr_output_head_v1_release
                : unsafe swl_zwlr_output_head_v1_destroy
        )
        do {
            try unsafe listenerOwner?.install(on: pointer)
        } catch {
            listenerOwner?.cancel()
            proxy.destroy()
            throw RuntimeError.fromRuntimeOrInvalidArgument(error)
        }
    }

    func trackMode(_ mode: RawWlrOutputMode) {
        modes.append(mode)
    }

    package func destroy() {
        listenerOwner?.cancel()
        for mode in modes {
            mode.destroy()
        }
        modes.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    func abandonAfterManagerFinished() {
        listenerOwner?.cancel()
        for mode in modes {
            mode.abandonAfterManagerFinished()
        }
        modes.removeAll(keepingCapacity: false)
        proxy.abandon()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawWlrOutputMode {
    private var proxy: RawOwnedProxy
    private let listenerOwner: RawWlrOutputModeListenerOwner?

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(pointer modePointer: OpaquePointer, version: RawVersion = RawVersion(3)) {
        listenerOwner = nil
        proxy = RawOwnedProxy(
            pointer: modePointer,
            destroy: version >= RawVersion(3)
                ? unsafe swl_zwlr_output_mode_v1_release
                : unsafe swl_zwlr_output_mode_v1_destroy
        )
    }

    @safe
    init(
        pointer modePointer: OpaquePointer,
        version modeVersion: RawVersion,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent: @escaping (RawWlrOutputModeEvent) -> Void
    ) throws(RuntimeError) {
        listenerOwner = RawWlrOutputModeListenerOwner(
            invariantFailureSink: failureSink,
            onEvent: onEvent
        )
        proxy = RawOwnedProxy(
            pointer: modePointer,
            destroy: modeVersion >= RawVersion(3)
                ? unsafe swl_zwlr_output_mode_v1_release
                : unsafe swl_zwlr_output_mode_v1_destroy
        )
        do {
            try unsafe listenerOwner?.install(on: pointer)
        } catch {
            listenerOwner?.cancel()
            proxy.destroy()
            throw RuntimeError.fromRuntimeOrInvalidArgument(error)
        }
    }

    package func destroy() {
        listenerOwner?.cancel()
        proxy.destroy()
    }

    func abandonAfterManagerFinished() {
        listenerOwner?.cancel()
        proxy.abandon()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawWlrOutputConfiguration {
    private var proxy: RawOwnedProxy
    private let listenerOwner: RawWlrOutputConfigurationListenerOwner?

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer configurationPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onEvent: ((RawWlrOutputConfigurationEvent) -> Void)? = nil
    ) throws(RuntimeError) {
        listenerOwner = onEvent.map { eventHandler in
            RawWlrOutputConfigurationListenerOwner(
                invariantFailureSink: failureSink,
                onEvent: eventHandler
            )
        }
        proxy = RawOwnedProxy(
            pointer: configurationPointer,
            destroy: unsafe swl_zwlr_output_configuration_v1_destroy
        )
        do {
            try unsafe listenerOwner?.install(on: pointer)
        } catch {
            listenerOwner?.cancel()
            proxy.destroy()
            throw RuntimeError.fromRuntimeOrInvalidArgument(error)
        }
    }

    package func enable(head: RawWlrOutputHead) throws -> RawWlrOutputConfigurationHead {
        guard
            let configurationHead = unsafe swl_zwlr_output_configuration_v1_enable_head(
                pointer,
                head.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwlr_output_configuration_head_v1")
        }

        return RawWlrOutputConfigurationHead(pointer: configurationHead)
    }

    package func disable(head: RawWlrOutputHead) {
        unsafe swl_zwlr_output_configuration_v1_disable_head(pointer, head.pointer)
    }

    package func test() {
        unsafe swl_zwlr_output_configuration_v1_test(pointer)
    }

    package func apply() {
        unsafe swl_zwlr_output_configuration_v1_apply(pointer)
    }

    package func destroy() {
        listenerOwner?.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawWlrOutputConfigurationHead {
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(pointer headPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: headPointer,
            destroy: unsafe swl_zwlr_output_configuration_head_v1_destroy
        )
    }

    package func setMode(_ mode: RawWlrOutputMode) {
        unsafe swl_zwlr_output_configuration_head_v1_set_mode(pointer, mode.pointer)
    }

    package func setCustomMode(width: Int32, height: Int32, refresh: Int32) {
        unsafe swl_zwlr_output_configuration_head_v1_set_custom_mode(
            pointer,
            width,
            height,
            refresh
        )
    }

    package func setPosition(x: Int32, y: Int32) {
        unsafe swl_zwlr_output_configuration_head_v1_set_position(pointer, x, y)
    }

    package func setTransform(_ transform: Int32) {
        unsafe swl_zwlr_output_configuration_head_v1_set_transform(pointer, transform)
    }

    package func setScale(_ scale: WaylandFixed) {
        unsafe swl_zwlr_output_configuration_head_v1_set_scale(pointer, scale.rawValue)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
