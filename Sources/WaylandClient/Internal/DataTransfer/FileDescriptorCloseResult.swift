import Glibc

package enum FileDescriptorCloseResult: Equatable, Sendable {
    case closed
    case failed(WaylandSystemErrno)

    package static func posixReturn(
        _ result: Int32,
        errno rawErrno: Int32 = Glibc.errno
    ) -> Self {
        guard result == 0 else {
            return .failed(WaylandSystemErrno(capturingPOSIXErrno: rawErrno, fallback: EIO))
        }

        return .closed
    }

    package func throwIfFailed() throws {
        guard case .failed(let error) = self else {
            return
        }

        throw DataTransferError.closeFileDescriptor(error)
    }
}
