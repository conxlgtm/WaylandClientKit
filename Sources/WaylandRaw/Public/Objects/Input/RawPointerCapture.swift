// swiftlint:disable file_length

import CWaylandProtocols
import Glibc

package struct RawPointerConstraintLifetime: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue lifetimeRawValue: UInt32) {
        rawValue = lifetimeRawValue
    }

    package static let oneShot = Self(rawValue: 1)
    package static let persistent = Self(rawValue: 2)
}

@safe
package final class RawRelativePointerManager {
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
            interface: "zwp_relative_pointer_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_relative_pointer_manager_v1_destroy
        )
    }

    package func relativePointer(
        for seat: RawSeat,
        eventSink: RawInputEventSink
    ) throws -> RawRelativePointer {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }

        guard
            let relativePointer = unsafe swl_zwp_relative_pointer_manager_v1_get_relative_pointer(
                pointer,
                pointerDevice
            )
        else {
            throw RuntimeError.bindFailed("zwp_relative_pointer_v1")
        }

        let adoptedRelativePointer = try unsafe proxyAdoption.adoptOrDestroy(
            relativePointer,
            interface: "zwp_relative_pointer_v1",
            destroy: unsafe swl_zwp_relative_pointer_v1_destroy
        )

        return try RawRelativePointer(
            pointer: adoptedRelativePointer,
            version: version,
            seatID: seat.id,
            deviceID: seat.pointerDeviceID,
            eventSink: eventSink,
            invariantFailureSink: proxyAdoption.invariantFailureSink
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
package final class RawRelativePointer {
    package let version: RawVersion

    private let listenerOwner: RawRelativePointerOwner
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer relativePointer: OpaquePointer,
        version relativePointerVersion: RawVersion,
        seatID: RawSeatID,
        deviceID: RawInputDeviceID?,
        eventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) throws(RuntimeError) {
        version = relativePointerVersion
        proxy = RawOwnedProxy(
            pointer: relativePointer,
            destroy: unsafe swl_zwp_relative_pointer_v1_destroy
        )
        listenerOwner = RawRelativePointerOwner(
            seatID: seatID,
            deviceID: deviceID,
            eventSink: eventSink,
            invariantFailureSink: failureSink
        )
        try unsafe listenerOwner.install(on: relativePointer)
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
package final class RawPointerConstraints {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer constraintsPointer: OpaquePointer,
        version constraintsVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = constraintsVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: constraintsPointer,
            interface: "zwp_pointer_constraints_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_pointer_constraints_v1_destroy
        )
    }

    package func lockPointer(
        surface: RawSurface,
        seat: RawSeat,
        region: RawRegion?,
        lifetime: RawPointerConstraintLifetime,
        eventSink: RawInputEventSink
    ) throws -> RawLockedPointer {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }

        guard
            let lockedPointer = unsafe swl_zwp_pointer_constraints_v1_lock_pointer(
                pointer,
                surface.pointer,
                pointerDevice,
                region?.pointer,
                lifetime.rawValue
            )
        else {
            throw RuntimeError.bindFailed("zwp_locked_pointer_v1")
        }

        let adoptedLockedPointer = try unsafe proxyAdoption.adoptOrDestroy(
            lockedPointer,
            interface: "zwp_locked_pointer_v1",
            destroy: unsafe swl_zwp_locked_pointer_v1_destroy
        )

        return try RawLockedPointer(
            pointer: adoptedLockedPointer,
            version: version,
            seatID: seat.id,
            surfaceID: surface.objectID,
            invariantFailureSink: proxyAdoption.invariantFailureSink,
            eventSink: eventSink
        )
    }

    package func confinePointer(
        surface: RawSurface,
        seat: RawSeat,
        region: RawRegion?,
        lifetime: RawPointerConstraintLifetime,
        eventSink: RawInputEventSink
    ) throws -> RawConfinedPointer {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }

        guard
            let confinedPointer = unsafe swl_zwp_pointer_constraints_v1_confine_pointer(
                pointer,
                surface.pointer,
                pointerDevice,
                region?.pointer,
                lifetime.rawValue
            )
        else {
            throw RuntimeError.bindFailed("zwp_confined_pointer_v1")
        }

        let adoptedConfinedPointer = try unsafe proxyAdoption.adoptOrDestroy(
            confinedPointer,
            interface: "zwp_confined_pointer_v1",
            destroy: unsafe swl_zwp_confined_pointer_v1_destroy
        )

        return try RawConfinedPointer(
            pointer: adoptedConfinedPointer,
            version: version,
            seatID: seat.id,
            surfaceID: surface.objectID,
            invariantFailureSink: proxyAdoption.invariantFailureSink,
            eventSink: eventSink
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
package final class RawLockedPointer {
    package let version: RawVersion
    package let identity: RawPointerConstraintIdentity

    private let listenerOwner: RawLockedPointerOwner
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer lockedPointer: OpaquePointer,
        version lockedPointerVersion: RawVersion,
        seatID: RawSeatID,
        surfaceID: RawObjectID,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        eventSink: RawInputEventSink
    ) throws(RuntimeError) {
        version = lockedPointerVersion
        let objectID = unsafe RawObjectID(
            swl_proxy_get_id(UnsafeMutableRawPointer(lockedPointer))
        )
        identity = RawPointerConstraintIdentity(objectID: objectID, kind: .locked)
        proxy = RawOwnedProxy(
            pointer: lockedPointer,
            destroy: unsafe swl_zwp_locked_pointer_v1_destroy
        )
        listenerOwner = RawLockedPointerOwner(
            seatID: seatID,
            identity: identity,
            surfaceID: surfaceID,
            invariantFailureSink: failureSink,
            eventSink: eventSink
        )
        try unsafe listenerOwner.install(on: lockedPointer)
    }

    package func setCursorPositionHint(x: WaylandFixed, y: WaylandFixed) {
        unsafe swl_zwp_locked_pointer_v1_set_cursor_position_hint(
            pointer,
            x.rawValue,
            y.rawValue
        )
    }

    package func setRegion(_ region: RawRegion?) {
        unsafe swl_zwp_locked_pointer_v1_set_region(pointer, region?.pointer)
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
package final class RawConfinedPointer {
    package let version: RawVersion
    package let identity: RawPointerConstraintIdentity

    private let listenerOwner: RawConfinedPointerOwner
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer confinedPointer: OpaquePointer,
        version confinedPointerVersion: RawVersion,
        seatID: RawSeatID,
        surfaceID: RawObjectID,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        eventSink: RawInputEventSink
    ) throws(RuntimeError) {
        version = confinedPointerVersion
        let objectID = unsafe RawObjectID(
            swl_proxy_get_id(UnsafeMutableRawPointer(confinedPointer))
        )
        identity = RawPointerConstraintIdentity(objectID: objectID, kind: .confined)
        proxy = RawOwnedProxy(
            pointer: confinedPointer,
            destroy: unsafe swl_zwp_confined_pointer_v1_destroy
        )
        listenerOwner = RawConfinedPointerOwner(
            seatID: seatID,
            identity: identity,
            surfaceID: surfaceID,
            invariantFailureSink: failureSink,
            eventSink: eventSink
        )
        try unsafe listenerOwner.install(on: confinedPointer)
    }

    package func setRegion(_ region: RawRegion?) {
        unsafe swl_zwp_confined_pointer_v1_set_region(pointer, region?.pointer)
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
private final class RawRelativePointerOwner {
    private let seatID: RawSeatID
    private let deviceID: RawInputDeviceID?
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_relative_pointer_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_relative_pointer_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        seatID pointerSeatID: RawSeatID,
        deviceID pointerDeviceID: RawInputDeviceID?,
        eventSink inputEventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        seatID = pointerSeatID
        deviceID = pointerDeviceID
        eventSink = inputEventSink
        invariantFailureSink = failureSink

        // swiftlint:disable closure_parameter_position
        unsafe callbacks.pointee.relative_motion = {
            data, _, utimeHi, utimeLo, dx, dy, dxUnaccel, dyUnaccel in
            RawRelativePointerOwner.withOwner(
                data,
                message: "zwp_relative_pointer_v1 relative_motion fired without Swift state"
            ) { owner in
                let timestamp = (UInt64(utimeHi) << 32) | UInt64(utimeLo)
                owner.append(
                    RawRelativePointerMotion(
                        timestampMicroseconds: timestamp,
                        dx: WaylandFixed(rawValue: dx),
                        dy: WaylandFixed(rawValue: dy),
                        dxUnaccelerated: WaylandFixed(rawValue: dxUnaccel),
                        dyUnaccelerated: WaylandFixed(rawValue: dyUnaccel)
                    )
                )
            }
        }
        // swiftlint:enable closure_parameter_position
    }

    func install(on relativePointer: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_relative_pointer_v1_add_listener(
            relativePointer,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_relative_pointer_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ motion: RawRelativePointerMotion) {
        guard !isCanceled else { return }

        eventSink.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: deviceID,
                kind: .pointer(.relativeMotion(motion))
            )
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawRelativePointerOwner) -> Void
    ) {
        CListenerStorage<
            RawRelativePointerOwner,
            swl_zwp_relative_pointer_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawLockedPointerOwner {
    private let seatID: RawSeatID
    private let identity: RawPointerConstraintIdentity
    private let surfaceID: RawObjectID
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_locked_pointer_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_zwp_locked_pointer_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        seatID pointerSeatID: RawSeatID,
        identity constraintIdentity: RawPointerConstraintIdentity,
        surfaceID constraintSurfaceID: RawObjectID,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        eventSink inputEventSink: RawInputEventSink
    ) {
        seatID = pointerSeatID
        identity = constraintIdentity
        surfaceID = constraintSurfaceID
        invariantFailureSink = failureSink
        eventSink = inputEventSink

        unsafe callbacks.pointee.locked = { data, _ in
            RawLockedPointerOwner.withOwner(
                data,
                message: "zwp_locked_pointer_v1 locked fired without Swift state"
            ) { owner in
                owner.append(.locked(owner.identity, surfaceID: owner.surfaceID))
            }
        }

        unsafe callbacks.pointee.unlocked = { data, _ in
            RawLockedPointerOwner.withOwner(
                data,
                message: "zwp_locked_pointer_v1 unlocked fired without Swift state"
            ) { owner in
                owner.append(.unlocked(owner.identity, surfaceID: owner.surfaceID))
            }
        }
    }

    func install(on lockedPointer: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_locked_pointer_v1_add_listener(lockedPointer, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_locked_pointer_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawPointerConstraintEvent) {
        guard !isCanceled else { return }

        eventSink.append(
            RawInputEventDraft(seatID: seatID, kind: .pointer(.constraint(event)))
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawLockedPointerOwner) -> Void
    ) {
        CListenerStorage<
            RawLockedPointerOwner,
            swl_zwp_locked_pointer_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawConfinedPointerOwner {
    private let seatID: RawSeatID
    private let identity: RawPointerConstraintIdentity
    private let surfaceID: RawObjectID
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_confined_pointer_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_confined_pointer_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        seatID pointerSeatID: RawSeatID,
        identity constraintIdentity: RawPointerConstraintIdentity,
        surfaceID constraintSurfaceID: RawObjectID,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        eventSink inputEventSink: RawInputEventSink
    ) {
        seatID = pointerSeatID
        identity = constraintIdentity
        surfaceID = constraintSurfaceID
        invariantFailureSink = failureSink
        eventSink = inputEventSink

        unsafe callbacks.pointee.confined = { data, _ in
            RawConfinedPointerOwner.withOwner(
                data,
                message: "zwp_confined_pointer_v1 confined fired without Swift state"
            ) { owner in
                owner.append(.confined(owner.identity, surfaceID: owner.surfaceID))
            }
        }

        unsafe callbacks.pointee.unconfined = { data, _ in
            RawConfinedPointerOwner.withOwner(
                data,
                message: "zwp_confined_pointer_v1 unconfined fired without Swift state"
            ) { owner in
                owner.append(.unconfined(owner.identity, surfaceID: owner.surfaceID))
            }
        }
    }

    func install(on confinedPointer: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_confined_pointer_v1_add_listener(confinedPointer, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_confined_pointer_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawPointerConstraintEvent) {
        guard !isCanceled else { return }

        eventSink.append(
            RawInputEventDraft(seatID: seatID, kind: .pointer(.constraint(event)))
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawConfinedPointerOwner) -> Void
    ) {
        CListenerStorage<
            RawConfinedPointerOwner,
            swl_zwp_confined_pointer_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}
