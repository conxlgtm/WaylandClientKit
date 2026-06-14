import CWaylandProtocols

package struct RawCompositorSessionID: Equatable, Hashable, Sendable {
    package let value: String

    package init(_ sessionID: String) {
        value = sessionID
    }
}

package struct RawCompositorSessionReason: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue reasonRawValue: UInt32) {
        rawValue = reasonRawValue
    }

    package static let launch = Self(rawValue: 1)
    package static let recover = Self(rawValue: 2)
    package static let sessionRestore = Self(rawValue: 3)
}

package enum RawCompositorSessionEvent: Equatable, Sendable {
    case created(RawCompositorSessionID)
    case restored
    case replaced
}

package enum RawCompositorToplevelSessionEvent: Equatable, Sendable {
    case restored
}

@safe
package final class RawCompositorSessionManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

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
            interface: "xdg_session_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_session_manager_v1_destroy
        )
    }

    package func getSession(
        reason: RawCompositorSessionReason,
        existingID: RawCompositorSessionID? = nil,
        onEvent: @escaping (RawCompositorSessionEvent) -> Void
    ) throws -> RawCompositorSession {
        if let existingID {
            guard
                let sessionPointer = unsafe existingID.value.withCString({ sessionIDPointer in
                    unsafe swl_xdg_session_manager_v1_get_session(
                        pointer,
                        reason.rawValue,
                        sessionIDPointer
                    )
                })
            else {
                throw RuntimeError.bindFailed("xdg_session_v1")
            }

            return try unsafe makeSession(from: sessionPointer, onEvent: onEvent)
        }

        guard
            let sessionPointer = unsafe swl_xdg_session_manager_v1_get_session(
                pointer,
                reason.rawValue,
                nil
            )
        else {
            throw RuntimeError.bindFailed("xdg_session_v1")
        }

        return try unsafe makeSession(from: sessionPointer, onEvent: onEvent)
    }

    private func makeSession(
        from sessionPointer: OpaquePointer,
        onEvent: @escaping (RawCompositorSessionEvent) -> Void
    ) throws -> RawCompositorSession {
        let adoptedSessionPointer = try unsafe proxyAdoption.adoptOrDestroy(
            sessionPointer,
            interface: "xdg_session_v1",
            destroy: unsafe swl_xdg_session_v1_destroy
        )

        return try RawCompositorSession(
            pointer: adoptedSessionPointer,
            version: version,
            proxyAdoption: proxyAdoption,
            onEvent: onEvent
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawCompositorSession {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private let listenerOwner: RawCompositorSessionOwner
    private var proxy: RawOwnedProxy
    private var toplevelSessions: [RawCompositorToplevelSession] = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer sessionPointer: OpaquePointer,
        version sessionVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        onEvent: @escaping (RawCompositorSessionEvent) -> Void
    ) throws(RuntimeError) {
        version = sessionVersion
        proxyAdoption = adoptionContext
        proxy = RawOwnedProxy(
            pointer: sessionPointer,
            destroy: unsafe swl_xdg_session_v1_destroy
        )
        listenerOwner = RawCompositorSessionOwner(
            invariantFailureSink: adoptionContext.invariantFailureSink,
            onEvent: onEvent
        )
        try unsafe listenerOwner.install(on: sessionPointer)
    }

    package func addToplevel(
        _ toplevel: RawXDGTopLevel,
        name: String,
        onEvent: @escaping (RawCompositorToplevelSessionEvent) -> Void
    ) throws -> RawCompositorToplevelSession {
        guard
            let toplevelSessionPointer = unsafe name.withCString({ namePointer in
                unsafe swl_xdg_session_v1_add_toplevel(pointer, toplevel.pointer, namePointer)
            })
        else {
            throw RuntimeError.bindFailed("xdg_toplevel_session_v1")
        }

        return try unsafe makeToplevelSession(
            from: toplevelSessionPointer,
            onEvent: onEvent
        )
    }

    package func restoreToplevel(
        _ toplevel: RawXDGTopLevel,
        name: String,
        onEvent: @escaping (RawCompositorToplevelSessionEvent) -> Void
    ) throws -> RawCompositorToplevelSession {
        guard
            let toplevelSessionPointer = unsafe name.withCString({ namePointer in
                unsafe swl_xdg_session_v1_restore_toplevel(
                    pointer,
                    toplevel.pointer,
                    namePointer
                )
            })
        else {
            throw RuntimeError.bindFailed("xdg_toplevel_session_v1")
        }

        return try unsafe makeToplevelSession(
            from: toplevelSessionPointer,
            onEvent: onEvent
        )
    }

    package func removeToplevel(named name: String) {
        unsafe name.withCString { namePointer in
            unsafe swl_xdg_session_v1_remove_toplevel(pointer, namePointer)
        }
    }

    package func destroy() {
        listenerOwner.cancel()
        destroyToplevelSessions()
        proxy.destroy()
    }

    private func makeToplevelSession(
        from toplevelSessionPointer: OpaquePointer,
        onEvent: @escaping (RawCompositorToplevelSessionEvent) -> Void
    ) throws -> RawCompositorToplevelSession {
        let adoptedToplevelSessionPointer = try unsafe proxyAdoption.adoptOrDestroy(
            toplevelSessionPointer,
            interface: "xdg_toplevel_session_v1",
            destroy: unsafe swl_xdg_toplevel_session_v1_destroy
        )
        let toplevelSession = try RawCompositorToplevelSession(
            pointer: adoptedToplevelSessionPointer,
            invariantFailureSink: proxyAdoption.invariantFailureSink,
            onEvent: onEvent
        )
        toplevelSessions.append(toplevelSession)
        return toplevelSession
    }

    private func destroyToplevelSessions() {
        for toplevelSession in toplevelSessions {
            toplevelSession.destroy()
        }
        toplevelSessions.removeAll(keepingCapacity: false)
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawCompositorToplevelSession {
    private let listenerOwner: RawCompositorToplevelSessionOwner
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer toplevelSessionPointer: OpaquePointer,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent: @escaping (RawCompositorToplevelSessionEvent) -> Void
    ) throws(RuntimeError) {
        proxy = RawOwnedProxy(
            pointer: toplevelSessionPointer,
            destroy: unsafe swl_xdg_toplevel_session_v1_destroy
        )
        listenerOwner = RawCompositorToplevelSessionOwner(
            invariantFailureSink: failureSink,
            onEvent: onEvent
        )
        try unsafe listenerOwner.install(on: toplevelSessionPointer)
    }

    package func rename(_ name: String) {
        unsafe name.withCString { namePointer in
            unsafe swl_xdg_toplevel_session_v1_rename(pointer, namePointer)
        }
    }

    package func destroy() {
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class RawCompositorSessionOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawCompositorSessionEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_session_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_xdg_session_v1_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent handler: @escaping (RawCompositorSessionEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = handler

        unsafe callbacks.pointee.created = { data, _, sessionID in
            RawCompositorSessionOwner.withOwner(
                data,
                message: "xdg_session_v1 created fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let sessionID = stringFromNullableCString(sessionID)
                else { return }
                owner.onEvent(.created(RawCompositorSessionID(sessionID)))
            }
        }
        unsafe callbacks.pointee.restored = { data, _ in
            RawCompositorSessionOwner.withOwner(
                data,
                message: "xdg_session_v1 restored fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onEvent(.restored)
            }
        }
        unsafe callbacks.pointee.replaced = { data, _ in
            RawCompositorSessionOwner.withOwner(
                data,
                message: "xdg_session_v1 replaced fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onEvent(.replaced)
            }
        }
    }

    func install(on session: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_xdg_session_v1_add_listener(session, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("xdg_session_v1")
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
        _ body: (RawCompositorSessionOwner) -> Void
    ) {
        CListenerStorage<RawCompositorSessionOwner, swl_xdg_session_v1_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawCompositorToplevelSessionOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawCompositorToplevelSessionEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_toplevel_session_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_xdg_toplevel_session_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent handler: @escaping (RawCompositorToplevelSessionEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = handler

        unsafe callbacks.pointee.restored = { data, _ in
            RawCompositorToplevelSessionOwner.withOwner(
                data,
                message: "xdg_toplevel_session_v1 restored fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.onEvent(.restored)
            }
        }
    }

    func install(on toplevelSession: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_xdg_toplevel_session_v1_add_listener(
            toplevelSession,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("xdg_toplevel_session_v1")
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
        _ body: (RawCompositorToplevelSessionOwner) -> Void
    ) {
        CListenerStorage<
            RawCompositorToplevelSessionOwner,
            swl_xdg_toplevel_session_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}
