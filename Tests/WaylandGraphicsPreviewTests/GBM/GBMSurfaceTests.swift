import CGBMShims
import Glibc
import Testing

@testable import WaylandGraphicsCore
@testable import WaylandRaw

@Suite(.serialized)
struct GBMSurfaceTests {
    @Test
    func surfaceDescriptorCapturesDmabufSelection() throws {
        let size = try GBMBufferSize(width: 320, height: 240)
        let formatModifier = RawLinuxDmabufFormatModifier(
            format: GBMDRMFormat.xrgb8888,
            modifier: GBMDRMModifier.invalid
        )

        let descriptor = GBMSurfaceDescriptor(
            size: size,
            formatModifier: formatModifier,
            flags: [.rendering, .linear]
        )

        #expect(descriptor.size == size)
        #expect(descriptor.format == GBMDRMFormat.xrgb8888)
        #expect(descriptor.modifier == GBMDRMModifier.invalid)
        #expect(descriptor.flags == [.rendering, .linear])
    }

    @Test
    func destroyReleasesLockedBufferAndInvalidatesLease() throws {
        let surfacePointer = try unsafe #require(OpaquePointer(bitPattern: 0x7007))
        let bufferPointer = try unsafe #require(OpaquePointer(bitPattern: 0x8008))
        let renderNodeDescriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(renderNodeDescriptors.readEnd)
        }
        let renderNode = try GBMRenderNodeFileDescriptor(
            adopting: renderNodeDescriptors.writeEnd
        )
        let device = GBMDevice(
            testingAdoptingRenderNodeFileDescriptor: renderNode
        )
        let surface = unsafe GBMSurface(
            testingAdoptingSurfacePointer: surfacePointer,
            device: device
        )
        let lockedBuffer = unsafe surface.testingRegisterLockedBuffer(pointer: bufferPointer)
        let expectedSurfaceAddress = Int(
            bitPattern: unsafe UnsafeMutableRawPointer(surfacePointer)
        )
        let expectedBufferAddress = Int(
            bitPattern: unsafe UnsafeMutableRawPointer(bufferPointer)
        )

        swl_test_gbm_surface_lifecycle_recording_begin()
        defer {
            swl_test_gbm_surface_lifecycle_recording_end()
        }

        surface.destroy()
        let destroyRecord = unsafe swl_test_gbm_surface_lifecycle_record()
        let destroyReleaseCallCount = unsafe destroyRecord.release_call_count
        let destroyCallCount = unsafe destroyRecord.destroy_call_count
        let destroyExportCallCount = unsafe destroyRecord.export_call_count
        let destroySurfaceAddress = Int(bitPattern: unsafe destroyRecord.surface)
        let destroyBufferAddress = Int(bitPattern: unsafe destroyRecord.buffer)

        #expect(destroyReleaseCallCount == 1)
        #expect(destroyCallCount == 1)
        #expect(destroyExportCallCount == 0)
        #expect(destroySurfaceAddress == expectedSurfaceAddress)
        #expect(destroyBufferAddress == expectedBufferAddress)
        #expect(throws: GBMAllocationError.bufferDestroyed) {
            _ = try lockedBuffer.exportDmabuf()
        }

        lockedBuffer.release()
        let releaseRecord = unsafe swl_test_gbm_surface_lifecycle_record()
        let releaseCallCount = unsafe releaseRecord.release_call_count
        let releaseExportCallCount = unsafe releaseRecord.export_call_count

        #expect(releaseCallCount == 1)
        #expect(releaseExportCallCount == 0)
    }

    @Test
    func lockedBufferExportUsesLivePointer() throws {
        let surfacePointer = try unsafe #require(OpaquePointer(bitPattern: 0x7107))
        let bufferPointer = try unsafe #require(OpaquePointer(bitPattern: 0x8108))
        let renderNodeDescriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(renderNodeDescriptors.readEnd)
        }
        let renderNode = try GBMRenderNodeFileDescriptor(
            adopting: renderNodeDescriptors.writeEnd
        )
        let device = GBMDevice(
            testingAdoptingRenderNodeFileDescriptor: renderNode
        )
        let surface = unsafe GBMSurface(
            testingAdoptingSurfacePointer: surfacePointer,
            device: device
        )
        let lockedBuffer = unsafe surface.testingRegisterLockedBuffer(pointer: bufferPointer)
        let expectedBufferAddress = Int(
            bitPattern: unsafe UnsafeMutableRawPointer(bufferPointer)
        )

        swl_test_gbm_surface_lifecycle_recording_begin()
        defer {
            swl_test_gbm_surface_lifecycle_recording_end()
        }

        #expect(throws: GBMAllocationError.exportFailed(errno: EINVAL)) {
            _ = try lockedBuffer.exportDmabuf()
        }

        let exportRecord = unsafe swl_test_gbm_surface_lifecycle_record()
        let exportCallCount = unsafe exportRecord.export_call_count
        let exportBufferAddress = Int(bitPattern: unsafe exportRecord.buffer)

        #expect(exportCallCount == 1)
        #expect(exportBufferAddress == expectedBufferAddress)

        lockedBuffer.release()
        surface.destroy()
    }
}
