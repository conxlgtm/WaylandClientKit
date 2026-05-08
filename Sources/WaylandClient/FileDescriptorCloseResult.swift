import Glibc

package enum FileDescriptorCloseResult: Equatable, Sendable {
    case closed
    case failed(WaylandSystemErrno)

    package static func posixReturn(
        _ result: Int32,
        errno rawErrno: Int32 = Glibc.errno
    ) -> Self {
        guard result == 0 else {
            return .failed(WaylandSystemErrno(unchecked: rawErrno > 0 ? rawErrno : EIO))
        }

        return .closed
    }
}
