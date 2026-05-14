import CGBMShims
import WaylandRaw

package struct GBMSurfaceDescriptor: Equatable, Sendable {
    package let size: GBMBufferSize
    package let format: UInt32
    package let modifier: UInt64
    package let flags: GBMBufferUseFlags

    package init(
        size surfaceSize: GBMBufferSize,
        formatModifier selectedFormatModifier: RawLinuxDmabufFormatModifier,
        flags surfaceFlags: GBMBufferUseFlags = .windowRendering
    ) {
        size = surfaceSize
        format = selectedFormatModifier.format
        modifier = selectedFormatModifier.modifier
        flags = surfaceFlags
    }
}

@safe
package final class GBMSurface {
    private var pointer: OpaquePointer?
    private let device: GBMDevice
    private var lockedBuffers: [ObjectIdentifier: WeakGBMLockedSurfaceBuffer] = [:]

    @safe
    package init(
        device surfaceDevice: GBMDevice,
        descriptor: GBMSurfaceDescriptor
    ) throws(GBMAllocationError) {
        let surfacePointer = try surfaceDevice.withUnsafeDevicePointer { devicePointer in
            unsafe swl_gbm_surface_create_for_modifier(
                devicePointer,
                descriptor.size.width,
                descriptor.size.height,
                descriptor.format,
                descriptor.modifier,
                descriptor.flags.rawValue
            )
        }
        guard let surfacePointer = unsafe surfacePointer else {
            throw GBMAllocationError.surfaceCreationFailed(
                format: descriptor.format,
                modifier: descriptor.modifier,
                flags: descriptor.flags.rawValue,
                errno: GBMAllocationError.capturedErrno()
            )
        }

        unsafe pointer = surfacePointer
        device = surfaceDevice
    }

    package init(
        testingAdoptingSurfacePointer surfacePointer: OpaquePointer,
        device surfaceDevice: GBMDevice
    ) {
        unsafe pointer = surfacePointer
        device = surfaceDevice
    }

    @safe
    package func withUnsafeSurfacePointer<Result>(
        _ body: (OpaquePointer) throws -> Result
    ) throws -> Result {
        guard let surfacePointer = unsafe pointer else {
            throw GBMAllocationError.surfaceDestroyed
        }

        return unsafe try body(surfacePointer)
    }

    @safe
    package func lockFrontBuffer() throws(GBMAllocationError) -> GBMLockedSurfaceBuffer {
        guard let surfacePointer = unsafe pointer else {
            throw GBMAllocationError.surfaceDestroyed
        }
        guard
            let bufferPointer = unsafe swl_gbm_surface_lock_front_buffer(surfacePointer)
        else {
            throw GBMAllocationError.surfaceFrontBufferLockFailed(
                errno: GBMAllocationError.capturedErrno()
            )
        }

        let lockedBuffer = GBMLockedSurfaceBuffer(
            pointer: bufferPointer,
            surface: self,
            device: device
        )
        registerLockedBuffer(lockedBuffer)
        return lockedBuffer
    }

    package func destroy() {
        guard let surfacePointer = unsafe pointer else { return }

        unsafe self.pointer = nil
        unsafe releaseLockedBuffersBeforeSurfaceDestroy(surfacePointer: surfacePointer)
        unsafe swl_gbm_surface_destroy(surfacePointer)
    }

    deinit {
        destroy()
    }

    package func testingRegisterLockedBuffer(
        pointer bufferPointer: OpaquePointer
    ) -> GBMLockedSurfaceBuffer {
        let lockedBuffer = GBMLockedSurfaceBuffer(
            pointer: bufferPointer,
            surface: self,
            device: device
        )
        registerLockedBuffer(lockedBuffer)
        return lockedBuffer
    }

    private func registerLockedBuffer(_ lockedBuffer: GBMLockedSurfaceBuffer) {
        lockedBuffers[ObjectIdentifier(lockedBuffer)] = WeakGBMLockedSurfaceBuffer(lockedBuffer)
    }

    func releaseLockedBuffer(
        _ lockedBuffer: GBMLockedSurfaceBuffer,
        bufferPointer: OpaquePointer
    ) {
        lockedBuffers[ObjectIdentifier(lockedBuffer)] = nil
        guard let surfacePointer = unsafe pointer else {
            return
        }

        unsafe swl_gbm_surface_release_buffer(surfacePointer, bufferPointer)
    }

    private func releaseLockedBuffersBeforeSurfaceDestroy(surfacePointer: OpaquePointer) {
        let liveBuffers = lockedBuffers.values.compactMap(\.lockedBuffer)
        lockedBuffers.removeAll()

        for lockedBuffer in liveBuffers {
            unsafe lockedBuffer.releaseBeforeSurfaceDestroy(surfacePointer: surfacePointer)
        }
    }
}

@safe
package final class GBMLockedSurfaceBuffer {
    private var pointer: OpaquePointer?
    private let surface: GBMSurface
    private let device: GBMDevice

    @safe
    package init(
        pointer bufferPointer: OpaquePointer,
        surface bufferSurface: GBMSurface,
        device bufferDevice: GBMDevice
    ) {
        unsafe pointer = bufferPointer
        surface = bufferSurface
        device = bufferDevice
    }

    @safe
    package func exportDmabuf() throws(GBMAllocationError) -> GBMDmabufExport {
        guard let bufferPointer = unsafe pointer else {
            throw GBMAllocationError.bufferDestroyed
        }

        var exportedBuffer = swl_gbm_bo_export()
        guard unsafe swl_gbm_bo_export_dmabuf(bufferPointer, &exportedBuffer) == 0 else {
            throw GBMAllocationError.exportFailed(errno: GBMAllocationError.capturedErrno())
        }

        return GBMDmabufExport(adopting: exportedBuffer)
    }

    package func release() {
        guard let bufferPointer = unsafe pointer else { return }

        unsafe self.pointer = nil
        unsafe surface.releaseLockedBuffer(self, bufferPointer: bufferPointer)
    }

    deinit {
        release()
        _ = device
    }

    func releaseBeforeSurfaceDestroy(surfacePointer: OpaquePointer) {
        guard let bufferPointer = unsafe pointer else { return }

        unsafe self.pointer = nil
        unsafe swl_gbm_surface_release_buffer(surfacePointer, bufferPointer)
    }
}

private struct WeakGBMLockedSurfaceBuffer {
    weak var lockedBuffer: GBMLockedSurfaceBuffer?

    init(_ lockedBuffer: GBMLockedSurfaceBuffer) {
        self.lockedBuffer = lockedBuffer
    }
}
