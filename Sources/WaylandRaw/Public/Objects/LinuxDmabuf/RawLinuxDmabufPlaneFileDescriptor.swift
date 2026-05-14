import Glibc

package struct RawLinuxDmabufPlaneFileDescriptor: ~Copyable {
    private var storage: Int32?

    package init(adopting fileDescriptor: Int32) throws(RuntimeError) {
        guard fileDescriptor >= 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .validateArgument("dmabuf plane fd")
            )
        }

        storage = fileDescriptor
    }

    package var isClosed: Bool {
        storage == nil
    }

    package var rawValue: Int32 {
        guard let storage else {
            preconditionFailure("dmabuf plane file descriptor was already released")
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
