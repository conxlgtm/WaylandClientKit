import CWaylandProtocols

package enum RawFifoError: Error, Equatable, Sendable, CustomStringConvertible {
    case alreadyExists
    case surfaceDestroyed

    package var description: String {
        switch self {
        case .alreadyExists:
            "surface already has a FIFO object"
        case .surfaceDestroyed:
            "FIFO surface was destroyed"
        }
    }
}

package enum RawFifoConstraint: Equatable, Sendable {
    case setBarrier
    case waitBarrier
}

package enum RawCommitTimingError: Error, Equatable, Sendable, CustomStringConvertible {
    case timerAlreadyExists
    case invalidTimestamp
    case timestampAlreadyExists
    case surfaceDestroyed

    package var description: String {
        switch self {
        case .timerAlreadyExists:
            "surface already has a commit timer"
        case .invalidTimestamp:
            "commit timing timestamp has invalid nanoseconds"
        case .timestampAlreadyExists:
            "commit timing timestamp already exists for this commit cycle"
        case .surfaceDestroyed:
            "commit timing surface was destroyed"
        }
    }
}

package struct RawCommitTargetTime: Equatable, Sendable {
    package static let maximumNanosecondValue: UInt32 = 999_999_999

    package let seconds: UInt64
    package let nanoseconds: UInt32

    package init(seconds targetSeconds: UInt64, nanoseconds targetNanoseconds: UInt32)
        throws(RawCommitTimingError)
    {
        guard targetNanoseconds <= Self.maximumNanosecondValue else {
            throw RawCommitTimingError.invalidTimestamp
        }

        seconds = targetSeconds
        nanoseconds = targetNanoseconds
    }

    package var secondsHighBits: UInt32 {
        UInt32(seconds >> 32)
    }

    package var secondsLowBits: UInt32 {
        UInt32(seconds & 0xffff_ffff)
    }
}

@safe
package final class RawFifoManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer {
        proxy.pointer
    }

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
            interface: "wp_fifo_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_fifo_manager_v1_destroy
        )
    }

    package func fifo(for surface: RawSurface) throws(RuntimeError) -> RawFifo {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(RawFifoError.alreadyExists.description)
        }

        guard
            let fifo = unsafe swl_wp_fifo_manager_v1_get_fifo(pointer, surface.pointer)
        else {
            throw RuntimeError.bindFailed("wp_fifo_v1")
        }

        let adoptedFifo = try unsafe proxyAdoption.adoptOrDestroy(
            fifo,
            interface: "wp_fifo_v1",
            destroy: unsafe swl_wp_fifo_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawFifo(
            pointer: adoptedFifo,
            destroy: unsafe swl_wp_fifo_v1_destroy,
            onDestroy: { [weak self] in
                self?.surfaceIDs.remove(surfaceID)
            }
        )
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
package final class RawFifo {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    init(
        pointer fifoPointer: OpaquePointer,
        destroy destroyFifo: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = {}
    ) {
        proxy = RawOwnedProxy(pointer: fifoPointer, destroy: destroyFifo)
        onDestroy = handleDestroy
    }

    package func apply(_ constraint: RawFifoConstraint) {
        switch constraint {
        case .setBarrier:
            unsafe swl_wp_fifo_v1_set_barrier(pointer)
        case .waitBarrier:
            unsafe swl_wp_fifo_v1_wait_barrier(pointer)
        }
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
package final class RawCommitTimingManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer {
        proxy.pointer
    }

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
            interface: "wp_commit_timing_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_commit_timing_manager_v1_destroy
        )
    }

    package func timer(for surface: RawSurface) throws(RuntimeError) -> RawCommitTimer {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawCommitTimingError.timerAlreadyExists.description
            )
        }

        guard
            let timer = unsafe swl_wp_commit_timing_manager_v1_get_timer(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_commit_timer_v1")
        }

        let adoptedTimer = try unsafe proxyAdoption.adoptOrDestroy(
            timer,
            interface: "wp_commit_timer_v1",
            destroy: unsafe swl_wp_commit_timer_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawCommitTimer(
            pointer: adoptedTimer,
            destroy: unsafe swl_wp_commit_timer_v1_destroy,
            onDestroy: { [weak self] in
                self?.surfaceIDs.remove(surfaceID)
            }
        )
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
package final class RawCommitTimer {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false
    private var hasPendingTimestamp = false

    @safe private var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    init(
        pointer timerPointer: OpaquePointer,
        destroy destroyTimer: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = {}
    ) {
        proxy = RawOwnedProxy(pointer: timerPointer, destroy: destroyTimer)
        onDestroy = handleDestroy
    }

    package func setTimestamp(_ targetTime: RawCommitTargetTime)
        throws(RawCommitTimingError)
    {
        guard !hasPendingTimestamp else {
            throw RawCommitTimingError.timestampAlreadyExists
        }

        hasPendingTimestamp = true
        unsafe swl_wp_commit_timer_v1_set_timestamp(
            pointer,
            targetTime.secondsHighBits,
            targetTime.secondsLowBits,
            targetTime.nanoseconds
        )
    }

    package func markCommitted() {
        hasPendingTimestamp = false
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

