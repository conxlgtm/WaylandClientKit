import Glibc
import WaylandRaw

extension DataTransferPipeDescriptors {
    package static func makeOfferReceivePipe() throws -> Self {
        do {
            let descriptors = try RawFileDescriptor.pipeDescriptors()
            return Self(readEnd: descriptors.readEnd, writeEnd: descriptors.writeEnd)
        } catch {
            throw DataTransferError(pipeCreationError: error)
        }
    }
}

extension DataTransferError {
    package init(pipeCreationError error: RuntimeError) {
        switch error {
        case .system(let systemError):
            self = .createPipe(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
        case .systemErrnoUnavailable:
            self = .createPipe(WaylandSystemErrno(unchecked: EIO))
        default:
            self = .unavailable
        }
    }
}
