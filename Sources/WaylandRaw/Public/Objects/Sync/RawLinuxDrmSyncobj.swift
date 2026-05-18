import CWaylandProtocols
import Glibc

private func ignoreSyncobjProxyDestroy() {
    // Optional destruction hook for tests.
}

package enum RawLinuxDrmSyncobjError: Error, Equatable, Sendable, CustomStringConvertible {
    case surfaceAlreadyHasSyncObject
    case invalidTimeline
    case noSurface
    case unsupportedBuffer
    case noBuffer
    case noAcquirePoint
    case noReleasePoint
    case conflictingPoints

    package var description: String {
        switch self {
        case .surfaceAlreadyHasSyncObject:
            "surface already has a linux-drm-syncobj object"
        case .invalidTimeline:
            "invalid linux-drm-syncobj timeline"
        case .noSurface:
            "linux-drm-syncobj surface no longer has a wl_surface"
        case .unsupportedBuffer:
            "attached buffer does not support explicit synchronization"
        case .noBuffer:
            "syncobj timeline point was set without an attached buffer"
        case .noAcquirePoint:
            "explicit sync commit is missing acquire point"
        case .noReleasePoint:
            "explicit sync commit is missing release point"
        case .conflictingPoints:
            "acquire and release timeline points conflict"
        }
    }
}

package struct RawSyncobjTimelinePoint: Equatable, Sendable {
    package let rawValue: UInt64

    package init(_ pointValue: UInt64) {
        rawValue = pointValue
    }

    package var highBits: UInt32 {
        UInt32(rawValue >> 32)
    }

    package var lowBits: UInt32 {
        UInt32(rawValue & 0xffff_ffff)
    }
}

package struct RawDrmSyncobjTimelineFD: ~Copyable {
    private var storage: Int32?

    package init(adopting fileDescriptor: Int32) throws(RuntimeError) {
        guard fileDescriptor >= 0 else {
            throw RuntimeError.invalidArgument("drm syncobj timeline fd")
        }

        storage = fileDescriptor
    }

    package var isClosed: Bool {
        storage == nil
    }

    package var rawValue: Int32 {
        guard let storage else {
            preconditionFailure("drm syncobj timeline fd was already released")
        }

        return storage
    }

    package mutating func releaseForWaylandRequest() -> Int32 {
        let fd = rawValue
        storage = nil
        return fd
    }

    package mutating func close() {
        guard let fd = storage else { return }

        storage = nil
        Glibc.close(fd)
    }

    deinit {
        if let storage {
            Glibc.close(storage)
        }
    }
}

@safe
package final class RawLinuxDrmSyncobjManager {
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
            interface: "wp_linux_drm_syncobj_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_linux_drm_syncobj_manager_v1_destroy
        )
    }

    package func syncobjSurface(for surface: RawSurface) throws(RuntimeError)
        -> RawLinuxDrmSyncobjSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawLinuxDrmSyncobjError.surfaceAlreadyHasSyncObject.description
            )
        }

        guard
            let syncobjSurface = unsafe swl_wp_linux_drm_syncobj_manager_v1_get_surface(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_linux_drm_syncobj_surface_v1")
        }

        let adoptedSurface = try unsafe proxyAdoption.adoptOrDestroy(
            syncobjSurface,
            interface: "wp_linux_drm_syncobj_surface_v1",
            destroy: unsafe swl_wp_linux_drm_syncobj_surface_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawLinuxDrmSyncobjSurface(
            pointer: adoptedSurface,
            destroy: unsafe swl_wp_linux_drm_syncobj_surface_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func importTimeline(
        fileDescriptor: inout RawDrmSyncobjTimelineFD
    ) throws(RuntimeError) -> RawLinuxDrmSyncobjTimeline {
        let fd = fileDescriptor.releaseForWaylandRequest()
        defer { Glibc.close(fd) }

        guard
            let timeline = unsafe swl_wp_linux_drm_syncobj_manager_v1_import_timeline(
                pointer,
                fd
            )
        else {
            throw RuntimeError.bindFailed("wp_linux_drm_syncobj_timeline_v1")
        }

        let adoptedTimeline = try unsafe proxyAdoption.adoptOrDestroy(
            timeline,
            interface: "wp_linux_drm_syncobj_timeline_v1",
            destroy: unsafe swl_wp_linux_drm_syncobj_timeline_v1_destroy
        )
        return RawLinuxDrmSyncobjTimeline(
            pointer: adoptedTimeline,
            destroy: unsafe swl_wp_linux_drm_syncobj_timeline_v1_destroy
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
package final class RawLinuxDrmSyncobjTimeline {
    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    package init(
        pointer timelinePointer: OpaquePointer,
        destroy destroyTimeline: @escaping (OpaquePointer) -> Void
    ) {
        proxy = RawOwnedProxy(pointer: timelinePointer, destroy: destroyTimeline)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawLinuxDrmSyncobjSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe package var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    package init(
        pointer surfacePointer: OpaquePointer,
        destroy destroySurface: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSyncobjProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: surfacePointer, destroy: destroySurface)
        onDestroy = handleDestroy
    }

    package func setAcquirePoint(
        timeline: RawLinuxDrmSyncobjTimeline,
        point: RawSyncobjTimelinePoint
    ) {
        unsafe swl_wp_linux_drm_syncobj_surface_v1_set_acquire_point(
            pointer,
            timeline.pointer,
            point.highBits,
            point.lowBits
        )
    }

    package func setReleasePoint(
        timeline: RawLinuxDrmSyncobjTimeline,
        point: RawSyncobjTimelinePoint
    ) {
        unsafe swl_wp_linux_drm_syncobj_surface_v1_set_release_point(
            pointer,
            timeline.pointer,
            point.highBits,
            point.lowBits
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
