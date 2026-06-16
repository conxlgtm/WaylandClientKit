import CWaylandProtocols

package enum RawForeignToplevelHandleEvent {
    case closed
    case done
    case title(String)
    case appID(String)
    case identifier(String)
}

package enum RawForeignToplevelListEvent {
    case toplevel(RawForeignToplevelHandle)
    case handle(RawForeignToplevelHandle, RawForeignToplevelHandleEvent)
    case finished
}

@safe
package final class RawForeignToplevelList {
    package let version: RawVersion

    private var proxy: RawOwnedProxy
    private var handles: [RawForeignToplevelHandle] = []
    private var listenerOwner: RawForeignToplevelListListenerOwner?
    private var hasStopped = false
    private var hasDestroyed = false
    private var stoppedLifetimeRetainer: RawForeignToplevelList?

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer listPointer: OpaquePointer,
        version listVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        onEvent: ((RawForeignToplevelListEvent) -> Void)? = nil
    ) throws(RuntimeError) {
        version = listVersion
        proxy = try RawOwnedProxy(
            adopting: listPointer,
            interface: "ext_foreign_toplevel_list_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_ext_foreign_toplevel_list_v1_destroy
        )
        listenerOwner = onEvent.map { eventHandler in
            RawForeignToplevelListListenerOwner(
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

    private func handle(
        _ event: RawForeignToplevelListListenerEvent,
        onEvent eventHandler: @escaping (RawForeignToplevelListEvent) -> Void
    ) {
        switch event {
        case .toplevel(let pointer):
            let handleBox = WeakForeignToplevelHandleBox()
            let handle = RawForeignToplevelHandle(
                pointer: pointer,
                invariantFailureSink: listenerOwner?.invariantFailureSink
            ) { [handleBox] handleEvent in
                guard let handle = handleBox.value else { return }
                eventHandler(.handle(handle, handleEvent))
            }
            handleBox.value = handle
            handles.append(handle)
            eventHandler(.toplevel(handle))
        case .finished:
            eventHandler(.finished)
            destroyAfterFinished()
        }
    }

    package func stop() {
        guard !hasStopped, !hasDestroyed else { return }

        hasStopped = true
        unsafe swl_ext_foreign_toplevel_list_v1_stop(pointer)
        proxy.abandon()
        stoppedLifetimeRetainer = self
    }

    package func destroy() {
        guard !hasDestroyed else { return }
        guard hasStopped else {
            stop()
            return
        }
    }

    private func destroyAfterFinished() {
        guard !hasDestroyed else { return }

        hasDestroyed = true
        listenerOwner?.cancel()
        for handle in handles {
            handle.destroy()
        }
        handles.removeAll(keepingCapacity: false)
        unsafe swl_ext_foreign_toplevel_list_v1_destroy(pointer)
        proxy.abandon()
        stoppedLifetimeRetainer = nil
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawForeignToplevelHandle {
    private var proxy: RawOwnedProxy
    private let listenerOwner: RawForeignToplevelHandleListenerOwner?

    @safe
    init(
        pointer handlePointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onEvent: ((RawForeignToplevelHandleEvent) -> Void)? = nil
    ) {
        listenerOwner = onEvent.map { eventHandler in
            RawForeignToplevelHandleListenerOwner(
                invariantFailureSink: failureSink,
                onEvent: eventHandler
            )
        }
        proxy = RawOwnedProxy(
            pointer: handlePointer,
            destroy: unsafe swl_ext_foreign_toplevel_handle_v1_destroy
        )
        do {
            try unsafe listenerOwner?.install(on: proxy.pointer)
        } catch {
            listenerOwner?.cancel()
            proxy.destroy()
        }
    }

    @safe
    package static func testingHandle(pointer handlePointer: OpaquePointer)
        -> RawForeignToplevelHandle
    {
        RawForeignToplevelHandle(
            pointer: handlePointer,
            destroy: unsafe ignoreTestingDestroy
        )
    }

    private static func ignoreTestingDestroy(_ handlePointer: OpaquePointer?) {
        _ = unsafe handlePointer
    }

    @safe
    private init(
        pointer handlePointer: OpaquePointer,
        destroy destroyHandle: @escaping @Sendable (OpaquePointer?) -> Void
    ) {
        listenerOwner = nil
        proxy = RawOwnedProxy(
            pointer: handlePointer,
            destroy: destroyHandle
        )
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
private enum RawForeignToplevelListListenerEvent {
    case toplevel(OpaquePointer)
    case finished
}

private final class WeakForeignToplevelHandleBox {
    weak var value: RawForeignToplevelHandle?
}

@safe
private final class RawForeignToplevelListListenerOwner {
    let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawForeignToplevelListListenerEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_ext_foreign_toplevel_list_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_ext_foreign_toplevel_list_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent eventHandler: @escaping (RawForeignToplevelListListenerEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = eventHandler

        unsafe callbacks.pointee.toplevel = { data, _, toplevel in
            RawForeignToplevelListListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_list_v1 toplevel fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let toplevel = unsafe toplevel else { return }
                unsafe owner.onEvent(.toplevel(toplevel))
            }
        }
        unsafe callbacks.pointee.finished = { data, _ in
            RawForeignToplevelListListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_list_v1 finished fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onEvent(.finished)
            }
        }
    }

    func install(on list: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_ext_foreign_toplevel_list_v1_add_listener(
            list,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("ext_foreign_toplevel_list_v1")
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
        _ body: (RawForeignToplevelListListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawForeignToplevelListListenerOwner,
            swl_ext_foreign_toplevel_list_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawForeignToplevelHandleListenerOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawForeignToplevelHandleEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_ext_foreign_toplevel_handle_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_ext_foreign_toplevel_handle_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent eventHandler: @escaping (RawForeignToplevelHandleEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = eventHandler

        unsafe callbacks.pointee.closed = { data, _ in
            RawForeignToplevelHandleListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_handle_v1 closed fired without Swift state"
            ) { owner in
                owner.append(.closed)
            }
        }
        unsafe callbacks.pointee.done = { data, _ in
            RawForeignToplevelHandleListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_handle_v1 done fired without Swift state"
            ) { owner in
                owner.append(.done)
            }
        }
        unsafe callbacks.pointee.title = { data, _, title in
            RawForeignToplevelHandleListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_handle_v1 title fired without Swift state"
            ) { owner in
                guard let title = stringFromNullableCString(title) else { return }
                owner.append(.title(title))
            }
        }
        unsafe callbacks.pointee.app_id = { data, _, appID in
            RawForeignToplevelHandleListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_handle_v1 app_id fired without Swift state"
            ) { owner in
                guard let appID = stringFromNullableCString(appID) else { return }
                owner.append(.appID(appID))
            }
        }
        unsafe callbacks.pointee.identifier = { data, _, identifier in
            RawForeignToplevelHandleListenerOwner.withOwner(
                data,
                message:
                    "ext_foreign_toplevel_handle_v1 identifier fired without Swift state"
            ) { owner in
                guard let identifier = stringFromNullableCString(identifier)
                else { return }
                owner.append(.identifier(identifier))
            }
        }
    }

    func install(on handle: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_ext_foreign_toplevel_handle_v1_add_listener(
            handle,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("ext_foreign_toplevel_handle_v1")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawForeignToplevelHandleEvent) {
        guard !isCanceled else { return }
        onEvent(event)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawForeignToplevelHandleListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawForeignToplevelHandleListenerOwner,
            swl_ext_foreign_toplevel_handle_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}
