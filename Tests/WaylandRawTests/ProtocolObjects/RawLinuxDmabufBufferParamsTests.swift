import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct RawLinuxDmabufBufferParamsStateTests {
    @Test
    func prepareAddPlaneReleasesDescriptorForWaylandRequest() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        var state = RawLinuxDmabufBufferParamsState()

        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor
        )

        #expect(requestDescriptor == descriptors.readEnd)
        let descriptorWasReleased = planeDescriptor.isClosed
        #expect(descriptorWasReleased)
        #expect(Glibc.fcntl(requestDescriptor, F_GETFD) != -1)
        Glibc.close(requestDescriptor)
    }

    @Test
    func rejectedAddPlaneClosesDescriptor() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        var state = RawLinuxDmabufBufferParamsState()
        try state.prepareCreate()

        do {
            _ = try state.prepareAddPlane(fileDescriptor: &planeDescriptor)
            Issue.record("Expected add after create request to throw")
        } catch RawLinuxDmabufBufferParamsStateError.addAfterCreateRequest {
            let descriptorWasClosed = planeDescriptor.isClosed
            #expect(descriptorWasClosed)
            #expect(Glibc.fcntl(descriptors.readEnd, F_GETFD) == -1)
            #expect(errno == EBADF)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func tracksCreateFailedAndDestroyedLifecycle() throws {
        var state = RawLinuxDmabufBufferParamsState()

        #expect(state.lifecycle == .pending)
        try state.prepareCreate()
        #expect(state.lifecycle == .pending)
        state.markFailed()
        #expect(state.lifecycle == .failed)
        state.markDestroyed()
        #expect(state.lifecycle == .destroyed)
    }

    @Test
    func rejectsRepeatedCreateRequest() throws {
        var state = RawLinuxDmabufBufferParamsState()
        try state.prepareCreate()

        do {
            try state.prepareCreate()
            Issue.record("Expected repeated create request to throw")
        } catch RawLinuxDmabufBufferParamsStateError.createAfterCreateRequest {
            #expect(state.lifecycle == .pending)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func paramsFlagsPreserveUnknownBits() {
        let flags = RawLinuxDmabufBufferParamsFlags(
            rawValue: RawLinuxDmabufBufferParamsFlags.yInvert.rawValue | 0x8000_0000
        )

        #expect(flags.contains(.yInvert))
        #expect(flags.unknownRawValue == 0x8000_0000)
    }
}
