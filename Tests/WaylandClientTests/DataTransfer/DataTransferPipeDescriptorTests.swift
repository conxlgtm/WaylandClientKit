import Glibc
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferPipeDescriptorTests {
    @Test
    func makeOfferReceivePipeCreatesDistinctDescriptors() throws {
        let descriptors = try DataTransferPipeDescriptors.makeOfferReceivePipe()
        defer {
            Glibc.close(descriptors.readEnd)
            Glibc.close(descriptors.writeEnd)
        }

        #expect(descriptors.readEnd >= 0)
        #expect(descriptors.writeEnd >= 0)
        #expect(descriptors.readEnd != descriptors.writeEnd)
    }

    @Test
    func pipeCreationSystemErrorMapsToCreatePipe() {
        let error = RuntimeError.system(
            RawSystemError(uncheckedErrno: EMFILE, operation: .createPipe)
        )

        #expect(
            DataTransferError(pipeCreationError: error)
                == .createPipe(WaylandSystemErrno(unchecked: EMFILE))
        )
    }

    @Test
    func pipeCreationUnavailableErrnoMapsToEIO() {
        let error = RuntimeError.systemErrnoUnavailable(operation: .createPipe)

        #expect(
            DataTransferError(pipeCreationError: error)
                == .createPipe(WaylandSystemErrno(unchecked: EIO))
        )
    }

    @Test
    func nonSystemPipeCreationErrorMapsToUnavailable() {
        #expect(DataTransferError(pipeCreationError: .connectionFailed) == .unavailable)
    }
}
