import CWaylandProtocols

package enum RawWlrOutputManagerEvent {
    case head(RawWlrOutputHead)
    case headEvent(RawWlrOutputHead, RawWlrOutputHeadEvent)
    case modeEvent(RawWlrOutputHead, RawWlrOutputMode, RawWlrOutputModeEvent)
    case done(UInt32)
    case finished
}

package enum RawWlrOutputHeadEvent {
    case name(String)
    case description(String)
    case physicalSize(width: Int32, height: Int32)
    case mode(RawWlrOutputMode)
    case enabled(Bool)
    case currentMode(RawWlrOutputMode)
    case modeEvent(RawWlrOutputMode, RawWlrOutputModeEvent)
    case position(x: Int32, y: Int32)
    case transform(Int32)
    case scale(WaylandFixed)
    case finished
    case make(String)
    case model(String)
    case serialNumber(String)
    case adaptiveSync(UInt32)
}

package enum RawWlrOutputModeEvent: Equatable, Sendable {
    case size(width: Int32, height: Int32)
    case refresh(Int32)
    case preferred
    case finished
}

package enum RawWlrOutputConfigurationEvent: Equatable, Sendable {
    case succeeded
    case failed
    case cancelled
}

@safe
package final class RawWlrOutputManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var hasStopped = false
    private var hasFinished = false
    private var heads: [RawWlrOutputHead] = []
    private var listenerOwner: RawWlrOutputManagerListenerOwner?
    private var stoppedLifetimeRetainer: RawWlrOutputManager?

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        onEvent: ((RawWlrOutputManagerEvent) -> Void)? = nil
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "zwlr_output_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwlr_output_manager_v1_destroy
        )
        listenerOwner = onEvent.map { eventHandler in
            RawWlrOutputManagerListenerOwner(
                invariantFailureSink: adoptionContext.invariantFailureSink
            ) { [weak self] event in
                self?.handle(event, onEvent: eventHandler)
            }
        }
        do {
            try unsafe listenerOwner?.install(on: pointer)
        } catch {
            listenerOwner?.cancel()
            proxy.destroy()
            throw error
        }
    }

    @safe
    package init(
        testingPointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) {
        version = managerVersion
        proxyAdoption = adoptionContext
        listenerOwner = nil
        proxy = RawOwnedProxy(
            pointer: managerPointer,
            destroy: unsafe swl_zwlr_output_manager_v1_destroy
        )
    }

    private func handle(
        _ event: RawWlrOutputManagerListenerEvent,
        onEvent eventHandler: @escaping (RawWlrOutputManagerEvent) -> Void
    ) {
        switch event {
        case .head(let pointer):
            let headBox = WeakOutputHeadBox()
            do {
                let head = try RawWlrOutputHead(
                    pointer: pointer,
                    version: version,
                    invariantFailureSink: proxyAdoption.invariantFailureSink
                ) { [weak self, headBox] headEvent in
                    guard let self, let head = headBox.value else { return }
                    self.handle(
                        headEvent,
                        for: head,
                        onEvent: eventHandler
                    )
                }
                headBox.value = head
                heads.append(head)
                eventHandler(.head(head))
            } catch {
                return
            }
        case .done(let serial):
            eventHandler(.done(serial))
        case .finished:
            eventHandler(.finished)
            finish()
        }
    }

    private func handle(
        _ event: RawWlrOutputHeadEvent,
        for head: RawWlrOutputHead,
        onEvent eventHandler: (RawWlrOutputManagerEvent) -> Void
    ) {
        if case .mode(let mode) = event {
            head.trackMode(mode)
        } else if case .modeEvent(let mode, let modeEvent) = event {
            eventHandler(.modeEvent(head, mode, modeEvent))
            return
        }
        eventHandler(.headEvent(head, event))
    }

    package func createConfiguration(
        serial: UInt32,
        onEvent: ((RawWlrOutputConfigurationEvent) -> Void)? = nil
    ) throws -> RawWlrOutputConfiguration {
        guard !hasStopped else {
            throw RuntimeError.invalidArgument("zwlr_output_manager_v1 stopped")
        }

        guard
            let configuration = unsafe swl_zwlr_output_manager_v1_create_configuration(
                pointer,
                serial
            )
        else {
            throw RuntimeError.bindFailed("zwlr_output_configuration_v1")
        }

        let adoptedConfiguration = try unsafe proxyAdoption.adoptOrDestroy(
            configuration,
            interface: "zwlr_output_configuration_v1",
            destroy: unsafe swl_zwlr_output_configuration_v1_destroy
        )
        return try RawWlrOutputConfiguration(
            pointer: adoptedConfiguration,
            invariantFailureSink: proxyAdoption.invariantFailureSink,
            onEvent: onEvent
        )
    }

    package func stop() {
        guard !hasStopped, !hasFinished else { return }

        hasStopped = true
        unsafe swl_zwlr_output_manager_v1_stop(pointer)
        proxy.abandon()
        stoppedLifetimeRetainer = self
    }

    package func destroy() {
        stop()
    }

    private func finish() {
        guard !hasFinished else { return }

        hasFinished = true
        listenerOwner?.cancel()
        for head in heads {
            head.abandonAfterManagerFinished()
        }
        heads.removeAll(keepingCapacity: false)
        proxy.abandon()
        stoppedLifetimeRetainer = nil
    }

    deinit {
        destroy()
    }
}

@safe
private enum RawWlrOutputManagerListenerEvent {
    case head(OpaquePointer)
    case done(UInt32)
    case finished
}

private final class WeakOutputHeadBox {
    weak var value: RawWlrOutputHead?
}

@safe
private final class RawWlrOutputManagerListenerOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawWlrOutputManagerListenerEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwlr_output_manager_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_zwlr_output_manager_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent eventHandler: @escaping (RawWlrOutputManagerListenerEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = eventHandler

        unsafe callbacks.pointee.head = { data, _, head in
            RawWlrOutputManagerListenerOwner.withOwner(
                data,
                message: "zwlr_output_manager_v1 head fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let head = unsafe head else { return }
                unsafe owner.onEvent(.head(head))
            }
        }
        unsafe callbacks.pointee.done = { data, _, serial in
            RawWlrOutputManagerListenerOwner.withOwner(
                data,
                message: "zwlr_output_manager_v1 done fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onEvent(.done(serial))
            }
        }
        unsafe callbacks.pointee.finished = { data, _ in
            RawWlrOutputManagerListenerOwner.withOwner(
                data,
                message: "zwlr_output_manager_v1 finished fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onEvent(.finished)
            }
        }
    }

    func install(on manager: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwlr_output_manager_v1_add_listener(manager, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwlr_output_manager_v1")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawWlrOutputManagerListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawWlrOutputManagerListenerOwner,
            swl_zwlr_output_manager_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}
