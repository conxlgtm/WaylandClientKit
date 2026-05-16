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
            fileDescriptor: &planeDescriptor,
            planeIndex: 0
        )

        #expect(requestDescriptor == descriptors.readEnd)
        let descriptorWasReleased = planeDescriptor.isClosed
        #expect(descriptorWasReleased)
        #expect(state.planeIndices == Set([0]))
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
        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor,
            planeIndex: 0
        )
        Glibc.close(requestDescriptor)
        try state.prepareCreate()

        let rejectedDescriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(rejectedDescriptors.writeEnd)
        }
        var rejectedPlaneDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: rejectedDescriptors.readEnd
        )

        do {
            _ = try state.prepareAddPlane(
                fileDescriptor: &rejectedPlaneDescriptor,
                planeIndex: 1
            )
            Issue.record("Expected add after create request to throw")
        } catch RawLinuxDmabufBufferParamsStateError.addAfterCreateRequest {
            let descriptorWasClosed = rejectedPlaneDescriptor.isClosed
            #expect(descriptorWasClosed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func tracksCreateFailedAndDestroyedLifecycle() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        var state = RawLinuxDmabufBufferParamsState()

        #expect(state.lifecycle == .collecting)
        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor,
            planeIndex: 0
        )
        Glibc.close(requestDescriptor)
        try state.prepareCreate()
        #expect(state.lifecycle == .createRequested)
        try state.markFailed()
        #expect(state.lifecycle == .failed)
        state.markDestroyed()
        #expect(state.lifecycle == .destroyed)
    }

    @Test
    func rejectsRepeatedCreateRequest() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        var state = RawLinuxDmabufBufferParamsState()
        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor,
            planeIndex: 0
        )
        Glibc.close(requestDescriptor)
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
    func createWithoutPlanesIsRejectedBeforeWaylandRequest() {
        var state = RawLinuxDmabufBufferParamsState()

        #expect(throws: RawLinuxDmabufBufferParamsStateError.createWithoutPlanes) {
            try state.prepareCreate()
        }
        #expect(state.lifecycle == .collecting)
        #expect(state.planeIndices.isEmpty)
    }

    @Test
    func duplicatePlaneIndexClosesDescriptorAndThrows() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        var state = RawLinuxDmabufBufferParamsState()

        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor,
            planeIndex: 0
        )
        Glibc.close(requestDescriptor)

        let duplicateDescriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(duplicateDescriptors.writeEnd)
        }
        var duplicatePlaneDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: duplicateDescriptors.readEnd
        )

        #expect(throws: RawLinuxDmabufBufferParamsStateError.duplicatePlaneIndex(0)) {
            _ = try state.prepareAddPlane(
                fileDescriptor: &duplicatePlaneDescriptor,
                planeIndex: 0
            )
        }
        let duplicateDescriptorWasClosed = duplicatePlaneDescriptor.isClosed
        #expect(duplicateDescriptorWasClosed)
        #expect(state.planeIndices == Set([0]))
    }

    @Test
    func createAfterAtLeastOnePlaneTransitionsToCreateRequested() throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        var state = RawLinuxDmabufBufferParamsState()

        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor,
            planeIndex: 0
        )
        Glibc.close(requestDescriptor)
        try state.prepareCreate()

        #expect(state.lifecycle == .createRequested)
        #expect(state.planeIndices == Set([0]))
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
        #expect(flags.hasUnknownBits)
    }
}

@Suite(.serialized)
struct RawLinuxDmabufBufferParamsPlaneSetTests {
    @Test
    func rejectedPlaneDoesNotMutatePlaneSet() throws {
        var state = RawLinuxDmabufBufferParamsState()

        try addPlane(index: 0, to: &state)

        let duplicateDescriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(duplicateDescriptors.writeEnd)
        }
        var duplicatePlaneDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: duplicateDescriptors.readEnd
        )

        do {
            _ = try state.prepareAddPlane(
                fileDescriptor: &duplicatePlaneDescriptor,
                planeIndex: 0
            )
            Issue.record("Expected duplicate plane index to throw")
        } catch RawLinuxDmabufBufferParamsStateError.duplicatePlaneIndex(let planeIndex) {
            #expect(planeIndex == 0)
            #expect(state.planeIndices == Set([0]))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func createRejectsPlaneSetStartingAboveZero() throws {
        var state = RawLinuxDmabufBufferParamsState()

        try addPlane(index: 2, to: &state)

        #expect(throws: RawLinuxDmabufBufferParamsStateError.nonConsecutivePlaneIndices([2])) {
            try state.prepareCreate()
        }
        #expect(state.lifecycle == .collecting)
    }

    @Test
    func createRejectsGappedPlaneSet() throws {
        var state = RawLinuxDmabufBufferParamsState()

        try addPlane(index: 0, to: &state)
        try addPlane(index: 2, to: &state)

        #expect(
            throws: RawLinuxDmabufBufferParamsStateError.nonConsecutivePlaneIndices([0, 2])
        ) {
            try state.prepareCreate()
        }
        #expect(state.lifecycle == .collecting)
    }

    @Test
    func createAcceptsOutOfOrderConsecutivePlanes() throws {
        var state = RawLinuxDmabufBufferParamsState()

        try addPlane(index: 1, to: &state)
        try addPlane(index: 0, to: &state)
        try state.prepareCreate()

        #expect(state.lifecycle == .createRequested)
        #expect(state.planeIndices == Set([0, 1]))
    }

    private func addPlane(
        index planeIndex: UInt32,
        to state: inout RawLinuxDmabufBufferParamsState
    ) throws {
        let descriptors = try RawFileDescriptor.pipeDescriptors()
        defer {
            Glibc.close(descriptors.writeEnd)
        }
        var planeDescriptor = try RawLinuxDmabufPlaneFileDescriptor(
            adopting: descriptors.readEnd
        )
        let requestDescriptor = try state.prepareAddPlane(
            fileDescriptor: &planeDescriptor,
            planeIndex: planeIndex
        )
        Glibc.close(requestDescriptor)
    }
}
