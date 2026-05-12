import Glibc
import Testing

@testable import WaylandRaw

@Suite(.serialized)
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
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func tracksCreateFailedAndDestroyedLifecycle() throws {
        var state = RawLinuxDmabufBufferParamsState()

        #expect(state.lifecycle == .collecting)
        try state.prepareCreate()
        #expect(state.lifecycle == .createRequested)
        try state.markFailed()
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
            #expect(state.lifecycle == .createRequested)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func createdBeforeCreateRequestReportsInvariantFailure() {
        var state = RawLinuxDmabufBufferParamsState()

        #expect(throws: RawLinuxDmabufBufferParamsStateError.createdBeforeCreateRequest) {
            try state.markCreated()
        }
        #expect(state.lifecycle == .collecting)
    }

    @Test
    func failedBeforeCreateRequestReportsInvariantFailure() {
        var state = RawLinuxDmabufBufferParamsState()

        #expect(throws: RawLinuxDmabufBufferParamsStateError.failedBeforeCreateRequest) {
            try state.markFailed()
        }
        #expect(state.lifecycle == .collecting)
    }

    @Test
    func destroyBeforeCreateIsCancellationNotFailure() {
        var state = RawLinuxDmabufBufferParamsState()

        state.markDestroyed()

        #expect(state.lifecycle == .destroyed)
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
